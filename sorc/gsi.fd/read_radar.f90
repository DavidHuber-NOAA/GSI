!  SUBSET=NC006001 -- level 3 superobs
!  SUBSET=NC006002 -- level 2.5 superobs
subroutine read_radar(nread,ndata,nodata,infile,lunout,obstype,twind,sis)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    read_radar                    read radar radial winds
!   prgmmr: yang             org: np23                date: 1998-05-15
!
! abstract:  This routine reads radar radial wind files.
!
!            When running the gsi in regional mode, the code only
!            retains those observations that fall within the regional
!            domain
!
! program history log:
!   1998-05-15  yang, weiyu
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-06-16  treadon - update documentation
!   2004-07-29  treadon - add only to module use, add intent in/out
!   2005-06-10  devenyi/treadon - correct subset declaration
!   2005-08-02  derber - modify to use convinfo file
!   2005-09-08  derber - modify to use input group time window
!   2005-10-11  treadon - change convinfo read to free format
!   2005-10-17  treadon - add grid and earth relative obs location to output file
!   2005-10-18  treadon - remove array obs_load and call to sumload
!   2005-10-26  treadon - add routine tag to convinfo printout
!   2006-02-03  derber  - modify for new obs control and obs count
!   2006-02-08  derber  - modify to use new convinfo module
!   2006-02-24  derber  - modify to take advantage of convinfo module
!   2006-04-21  parrish - modify to use level 2, 2.5, and/or 3 radar wind 
!                         superobs, with qc based on vad wind data.
!   2006-05-23  parrish - interpolate model elevation to vad wind site
!   2006-07-28  derber  - use r1000 from constants
!
!   input argument list:
!     infile   - file from which to read BUFR data
!     lunout   - unit to which to write data for further processing
!     obstype  - observation type to process
!     twind    - input group time window (hours)
!
!   output argument list:
!     nread    - number of doppler lidar wind observations read
!     ndata    - number of doppler lidar wind profiles retained for further processing
!     nodata   - number of doppler lidar wind observations retained for further processing
!     sis      - satellite/instrument/sensor indicator
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_single,r_double,i_kind,i_byte
  use constants, only: izero,zero,half,one,deg2rad,rearth,rad2deg, &
                       one_tenth,r1000
  use qcmod, only: erradar_inflate,vadfile
  use obsmod, only: iadate
  use gridmod, only: regional,nlat,nlon,tll2xy,rlats,rlons,rotate_wind_ll2xy
  use convinfo, only: nconvtype,ctwind,cgross,cermax,cermin,cvar_b,cvar_pg, &
       ncmiter,ncgroup,ncnumgrp,icuse,ictype,icsubtype,ioctype
  implicit none 
  
! Declare passed variables
  character(10),intent(in):: obstype,infile
  character(20),intent(in):: sis
  real(r_kind),intent(in):: twind
  integer(i_kind),intent(in):: lunout
  integer(i_kind),intent(inout):: nread,ndata,nodata

! Declare local parameters
  integer(i_kind),parameter:: maxlevs=1500
  integer(i_kind),parameter:: maxdat=17
  integer(i_kind),parameter:: maxvad=500
! integer(i_kind),parameter:: maxvadbins=20
  integer(i_kind),parameter:: maxvadbins=15
  real(r_single),parameter:: r4_single = 4.0_r_single

  real(r_kind),parameter:: dzvad=304.8_r_kind  !  vad reports are every 1000 ft = 304.8 meters
  real(r_kind),parameter:: r3_5 = 3.5_r_kind
  real(r_kind),parameter:: r6 = 6.0_r_kind
  real(r_kind),parameter:: r8 = 8.0_r_kind
  real(r_kind),parameter:: r60 = 60.0_r_kind
  real(r_kind),parameter:: r90 = 90.0_r_kind
  real(r_kind),parameter:: r100 = 100.0_r_kind
  real(r_kind),parameter:: r200 = 200.0_r_kind
  real(r_kind),parameter:: r360=360.0_r_kind
  real(r_kind),parameter:: r400 = 400.0_r_kind
  real(r_kind),parameter:: r50000 = 50000.0_r_kind

! Declare local variables
  logical good,outside,good0,lexist1,lexist2
  
  character(10) date
  character(40) filename
  character(50) hdrstr,datstr
  character(8) subset,subset_check(2)
  character(30) outmessage
  
  integer(i_kind) lnbufr,i,k,levsmin,levsmax,levszero,maxobs
  integer(i_kind) nmrecs,ibadazm,ibadwnd,ibaddist,ibadheight,ibadvad,kthin
  integer(i_kind) iyr,imo,idy,ihr,imn,isc,ithin,iin
  integer(i_kind) ibadstaheight,ibaderror,notgood,idate,iheightbelowsta,ibadfit
  integer(i_kind) notgood0
  integer(i_kind) novadmatch,ioutofvadrange
  integer(i_kind) iy,im,idd,ihh,iy2,iret,levs,mincy,minobs,kx0,kxadd,kx,ireason
  integer(i_kind) nreal,nchanl,ilat,ilon,ikx
  integer(i_kind),dimension(5):: idate5
  integer(i_kind) ivad,ivadz,nvad
  
  real(r_kind) timeb,rmesh,usage
  real(r_kind) eradkm,dlat_earth,dlon_earth
  real(r_kind) dlat,dlon,staheight,tiltangle,clon,slon,clat,slat
  real(r_kind) timeo,clonh,slonh,clath,slath,cdist,dist
  real(r_kind) rwnd,azm,height,error,wqm
  real(r_kind) azm_earth,cosazm_earth,sinazm_earth,cosazm,sinazm
  real(r_kind):: zsges
  
  real(r_kind),dimension(maxdat):: cdata
  real(r_kind),allocatable,dimension(:,:):: cdata_all
  
  real(r_double) rstation_id
  real(r_double),dimension(10):: hdr
  character(8) cstaid
  character(4) this_staid
  equivalence (this_staid,cstaid)
  equivalence (cstaid,rstation_id)
  real(r_double),dimension(7,maxlevs):: radar_obs
  real(r_double),dimension(4,maxlevs):: vad_obs
  
  character(8) vadid(maxvad)
  real(r_kind) vadlat(maxvad),vadlon(maxvad),vadqm(maxvad,maxvadbins)
  real(r_kind) vadu(maxvad,maxvadbins),vadv(maxvad,maxvadbins)
  real(r_kind) vadcount(maxvad,maxvadbins)
  real(r_kind),dimension(maxvad,maxvadbins)::vadfit2,vadcount2,vadwgt2
  real(r_kind),dimension(maxvad,maxvadbins)::vadfit2_5,vadcount2_5,vadwgt2_5
  real(r_kind),dimension(maxvad,maxvadbins)::vadfit3,vadcount3,vadwgt3
  real(r_kind) zob,vadqmmin,vadqmmax
  integer(i_kind) level2(maxvad),level2_5(maxvad),level3(maxvad),level3_tossed_by_2_5(maxvad)
  integer(i_kind) loop,numcut
  integer(i_kind) numhits(0:maxvad)
  real(r_kind) cutlat(maxlevs),cutlon(maxlevs),cuthgt(maxlevs),cutazm(maxlevs)
  real(r_kind) cutwspd(maxlevs),cuttime(maxlevs),cuterror(maxlevs),cutreason(maxlevs)
  real(r_kind) timemax,timemin,errmax,errmin
  real(r_kind) dlatmax,dlonmax,dlatmin,dlonmin
  real(r_kind) xscale,xscalei
  integer(i_kind) max_rrr,nboxmax
  integer(i_kind) irrr,iaaa,iaaamax,iaaamin
  integer(i_byte),allocatable::nobs_box(:,:,:,:)
  real(r_kind) dlonvad,dlatvad,vadlon_earth,vadlat_earth
  real(r_single) this_stalat,this_stalon,this_stahgt,thistime,thislat,thislon
  real(r_single) thishgt,thisvr,corrected_azimuth,thiserr,corrected_tilt
  integer(i_kind) nsuper2_in,nsuper2_kept
  integer(i_kind) nsuper2_5_in,nsuper2_5_kept
  integer(i_kind) nsuper3_in,nsuper3_kept
  real(r_kind) errzmax
  real(r_kind) thisfit,thisvadspd,thisfit2,uob,vob,thiswgt
! real(r_kind) dist2min,dist2max
! real(r_kind) dist2_5min,dist2_5max
  real(r_kind) vad_leash
  
  data lnbufr/10/
  data ithin / -9 /
  data rmesh / -99.999 /
  data hdrstr / 'CLAT CLON SELV ANEL YEAR MNTH DAYS HOUR MINU MGPT' /
  data datstr / 'STDM SUPLAT SUPLON HEIT RWND RWAZ RSTD' /
  
!***********************************************************************************

! Check to see if radar wind files exist.  If none exist, exit this routine.
  inquire(file='radar_supobs_from_level2',exist=lexist1)
  inquire(file=infile,exist=lexist2)
  if (.not.lexist1 .and. .not.lexist2) goto 900


! Initialize variables
! vad_leash=.1_r_kind
  vad_leash=.3_r_kind
 !xscale=5000._r_kind
 !xscale=10000._r_kind
  xscale=20000._r_kind
  write(6,*)'READ_RADAR:  set vad_leash,xscale=',vad_leash,xscale
  write(6,*)'READ_RADAR:  set maxvadbins,maxbadbins*dzvad=',maxvadbins,&
       maxvadbins*dzvad
  xscalei=one/xscale
  max_rrr=nint(100000.0_r_kind*xscalei)
  nboxmax=1
  iaaamax=-huge(iaaamax)
  iaaamin=huge(iaaamin)


  eradkm=rearth*0.001_r_kind
  kx0=22500
  maxobs=2e6
  nreal=maxdat
  nchanl=0
  ilon=2
  ilat=3

  nmrecs=izero

  allocate(cdata_all(maxdat,maxobs))

  errzmax=zero
  nvad=izero
  vadlon=zero
  vadlat=zero
  vadqm=-99999
  vadu=zero
  vadv=zero
  vadcount=zero
  vadqmmax=-huge(vadqmmax)
  vadqmmin=huge(vadqmmin)


! First read in all vad winds so can use vad wind quality marks to decide 
! which radar data to keep
! Open, then read bufr data
  open(lnbufr,file=vadfile,form='unformatted')
  call openbf(lnbufr,'IN',lnbufr)
  call datelen(10)
  call readmg(lnbufr,subset,idate,iret)
  if(iret/=0) go to 20

  write(date,'( i10)') idate
  read (date,'(i4,3i2)') iy,im,idd,ihh 
  write(6,*)'READ_RADAR:  first read vad winds--use vad quality marks to qc 2.5/3 radar winds'
  write(6,*)'READ_RADAR:  vad wind bufr file date is ',iy,im,idd,ihh
  if(iy/=iadate(1).or.im/=iadate(2).or.idd/=iadate(3).or.&
       ihh/=iadate(4)) then
     write(6,*)'***READ_RADAR ERROR*** vad wind incompatable analysis ',&
          'and observation date/time'
     write(6,*)' year  anal/obs ',iadate(1),iy
     write(6,*)' month anal/obs ',iadate(2),im
     write(6,*)' day   anal/obs ',iadate(3),idd
     write(6,*)' hour  anal/obs ',iadate(4),ihh
     call stop2(92)
  end if

! Big loop over vadwnd bufr file
10 call readsb(lnbufr,iret)
     if(iret/=0) then
        call readmg(lnbufr,subset,idate,iret)
        if(iret/=0) go to 20
        go to 10
     end if
     nmrecs = nmrecs+1

!    Read header.  Extract station infomration
     call ufbint(lnbufr,hdr,6,1,levs,'SID XOB YOB DHR TYP SAID ')
     kx=nint(hdr(5))
     if(kx /= 224) go to 10       !  for now just hardwire vad wind type
                                  !  and don't worry about subtypes
!    Is vadwnd in convinfo file
     ikx=0
     do i=1,nconvtype
       if(kx == ictype(i)) then
         ikx=i
         exit
       end if
     end do
     if(ikx == 0) go to 10

!    Time check
     timeb=hdr(4)
     if(abs(timeb) > ctwind(ikx) .or. abs(timeb) > half) go to 10 ! outside time window 

!    Create table of vad lat-lons and quality marks in 500m increments
!    for cross-referencing bird qc against radar winds
     rstation_id=hdr(1)      !station id
     dlon_earth=hdr(2)       !station lat (degrees)
     dlat_earth=hdr(3)       !station lon (degrees)

     if (dlon_earth>=r360) dlon_earth=dlon_earth-r360
     if (dlon_earth<zero ) dlon_earth=dlon_earth+r360
     dlat_earth = dlat_earth * deg2rad
     dlon_earth = dlon_earth * deg2rad
     ivad=0
     if(nvad.gt.0) then
        do i=1,nvad
           if(modulo(rad2deg*abs(dlon_earth-vadlon(i)),r360).lt.one_tenth.and. &
                rad2deg*abs(dlat_earth-vadlat(i)).lt.one_tenth) then
              ivad=i
              exit
           end if
        end do
     end if
     if(ivad.eq.0) then
        nvad=nvad+1
        if(nvad.gt.maxvad) then
           write(6,*)'READ_RADAR:  ***ERROR*** MORE THAN ',maxvad,' RADARS:  PROGRAM STOPS'
           call stop2(84)
        end if
        ivad=nvad
        vadlon(ivad)=dlon_earth
        vadlat(ivad)=dlat_earth
        vadid(ivad)=cstaid
     end if

!    Update vadqm table
     call ufbint(lnbufr,vad_obs,4,maxlevs,levs,'ZOB WQM UOB VOB ')
     if(levs>maxlevs) then
        write(6,*)'READ_RADAR:  ***ERROR*** need to increase read_radar bufr size since ',&
             ' number of levs=',levs,' > maxlevs=',maxlevs
        call stop2(84)
     endif

     do k=1,levs
        wqm=vad_obs(2,k)
        zob=vad_obs(1,k)
        uob=vad_obs(3,k)
        vob=vad_obs(4,k)
        ivadz=nint(zob/dzvad)
        if(ivadz.lt.1.or.ivadz.gt.maxvadbins) cycle
        errzmax=max(abs(zob-ivadz*dzvad),errzmax)
        vadqm(ivad,ivadz)=max(vadqm(ivad,ivadz),wqm)
        vadqmmax=max(vadqmmax,wqm)
        vadqmmin=min(vadqmmin,wqm)
        vadu(ivad,ivadz)=vadu(ivad,ivadz)+uob
        vadv(ivad,ivadz)=vadv(ivad,ivadz)+vob
        vadcount(ivad,ivadz)=vadcount(ivad,ivadz)+one
     end do
     

! End of bufr read loop
  go to 10

! Normal exit
20 continue
  call closbf(lnbufr)


! Print vadwnd table
  if(nvad.gt.0) then
     do ivad=1,nvad
        do ivadz=1,maxvadbins
           vadu(ivad,ivadz)=vadu(ivad,ivadz)/max(one,vadcount(ivad,ivadz))
           vadv(ivad,ivadz)=vadv(ivad,ivadz)/max(one,vadcount(ivad,ivadz))
        end do
        write(6,'(" n,lat,lon,qm=",i3,2f8.2,2x,25i3)') &
             ivad,vadlat(ivad)*rad2deg,vadlon(ivad)*rad2deg,(max(-9,nint(vadqm(ivad,k))),k=1,maxvadbins)
     end do
  end if
  write(6,*)' errzmax=',errzmax
  
!  Allocate thinning grids around each radar
!  space needed is nvad*max_rrr*max_rrr*8*max_zzz
!
!      max_rrr=20
!      maxvadbins=20
!      nvad=150
!      space=150*20*20*8*20 = 64000*150=9600000  peanuts
  
  allocate(nobs_box(max_rrr,8*max_rrr,maxvadbins,nvad))
  nobs_box=0

! Set level2_5 to 0.  Then loop over routine twice, first looking for
! level 2.5 data, and setting level2_5=count of 2.5 data for any 2.5 data
! available that passes the vad tests.  The second pass puts in level 3
! data where it is available and no level 2.5 data was saved/available 
! (level2_5=0)

  dlatmax=-huge(dlatmax)
  dlonmax=-huge(dlonmax)
  dlatmin=huge(dlatmin)
  dlonmin=huge(dlonmin)
  vadfit2=zero
  vadfit2_5=zero
  vadfit3=zero
  vadcount2=0
  vadcount2_5=0
  vadcount3=0
  level2=0
  level2_5=0
  level3=0
  level3_tossed_by_2_5=0
  subset_check(1)='NC006002'
  subset_check(2)='NC006001'

! First process any level 2 superobs.
! Initialize variables.
  ikx=0
  do i=1,nconvtype
     if(trim(ioctype(i)) == trim(obstype))ikx = i
  end do
  
  timemax=-huge(timemax)
  timemin=huge(timemin)
  errmax=-huge(errmax)
  errmin=huge(errmin)
  loop=0

  numhits=0
  ibadazm=izero
  ibadwnd=izero
  ibaddist=izero
  ibadheight=izero
  ibadstaheight=izero
  iheightbelowsta=izero
  ibaderror=izero
  ibadvad=0
  ibadfit=0
  ioutofvadrange=izero
  kthin=0
  novadmatch=izero
  notgood=izero
  notgood0=izero
  nsuper2_in=0
  nsuper2_kept=0

  if(loop.eq.0) outmessage='level 2 superobs:'

! Open sequential file containing superobs
  open(lnbufr,file='radar_supobs_from_level2',form='unformatted')
  rewind lnbufr

 ! dist2max=-huge(dist2max)
 ! dist2min=huge(dist2min)

! Loop to read superobs data file
  do
     read(lnbufr,iostat=iret)this_staid,this_stalat,this_stalon,this_stahgt, &
          thistime,thislat,thislon,thishgt,thisvr,corrected_azimuth,thiserr,corrected_tilt
     if(iret.ne.0) exit
     nsuper2_in=nsuper2_in+1

     dlat_earth=this_stalat    !station lat (degrees)
     dlon_earth=this_stalon    !station lon (degrees)
     if (dlon_earth>=r360) dlon_earth=dlon_earth-r360
     if (dlon_earth<zero ) dlon_earth=dlon_earth+r360
     dlat_earth = dlat_earth * deg2rad
     dlon_earth = dlon_earth * deg2rad
     
     if(regional)then
        call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
        if (outside) cycle
        dlatmax=max(dlat,dlatmax)
        dlonmax=max(dlon,dlonmax)
        dlatmin=min(dlat,dlatmin)
        dlonmin=min(dlon,dlonmin)
     else
        dlat = dlat_earth
        dlon = dlon_earth
        call grdcrd(dlat,1,rlats,nlat,1)
        call grdcrd(dlon,1,rlons,nlon,1)
     endif
     
     clon=cos(dlon_earth)
     slon=sin(dlon_earth)
     clat=cos(dlat_earth)
     slat=sin(dlat_earth)
     staheight=this_stahgt    !station elevation
     tiltangle=corrected_tilt*deg2rad

!    Find vad wind match
     ivad=0
     do k=1,nvad
        cdist=sin(vadlat(k))*slat+cos(vadlat(k))*clat* &
             (sin(vadlon(k))*slon+cos(vadlon(k))*clon)
        cdist=max(-one,min(cdist,one))
        dist=acosd(cdist)
        
        if(dist < 0.2_r_kind) then
           ivad=k
           exit
        end if
     end do
     numhits(ivad)=numhits(ivad)+1
     if(ivad==0) then
        novadmatch=novadmatch+1
        cycle
     end if
     
     vadlon_earth=vadlon(ivad)
     vadlat_earth=vadlat(ivad)
     if(regional)then
        call tll2xy(vadlon_earth,vadlat_earth,dlonvad,dlatvad,outside)
        if (outside) cycle
        dlatmax=max(dlatvad,dlatmax)
        dlonmax=max(dlonvad,dlonmax)
        dlatmin=min(dlatvad,dlatmin)
        dlonmin=min(dlonvad,dlonmin)
     else
        dlatvad = vadlat_earth
        dlonvad = vadlon_earth
        call grdcrd(dlatvad,1,rlats,nlat,1)
        call grdcrd(dlonvad,1,rlons,nlon,1)
     endif

!    Get model terrain at VAD wind location
     call deter_zsfc_model(dlatvad,dlonvad,zsges)
     
     timeo=thistime
     timemax=max(timemax,timeo)
     timemin=min(timemin,timeo)
     
!    Exclude data if it does not fall within time window
     if(abs(timeo)>half ) cycle

!    Get observation (lon,lat).  Compute distance from radar.
     dlat_earth=thislat
     dlon_earth=thislon
     if(dlon_earth>=r360) dlon_earth=dlon_earth-r360
     if(dlon_earth<zero ) dlon_earth=dlon_earth+r360
     
     dlat_earth = dlat_earth*deg2rad
     dlon_earth = dlon_earth*deg2rad
     if(regional) then
        call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
        if (outside) cycle
     else
        dlat = dlat_earth
        dlon = dlon_earth
        call grdcrd(dlat,1,rlats,nlat,1)
        call grdcrd(dlon,1,rlons,nlon,1)
     endif
     
     clonh=cos(dlon_earth)
     slonh=sin(dlon_earth)
     clath=cos(dlat_earth)
     slath=sin(dlat_earth)
     cdist=slat*slath+clat*clath*(slon*slonh+clon*clonh)
     cdist=max(-one,min(cdist,one))
     dist=eradkm*acos(cdist)
     irrr=nint(dist*1000*xscalei)
     if(irrr<=0 .or. irrr>max_rrr) cycle

!    Extract radial wind data
     height= thishgt
     rwnd  = thisvr
     azm_earth = corrected_azimuth
     if(regional) then
        cosazm_earth=cosd(azm_earth)
        sinazm_earth=sind(azm_earth)
        call rotate_wind_ll2xy(cosazm_earth,sinazm_earth,cosazm,sinazm,dlon_earth,dlat_earth,dlon,dlat)
        azm=atan2d(sinazm,cosazm)
     else
        azm=azm_earth
     end if
     iaaa=azm/(r360/(r8*irrr))
     iaaa=mod(iaaa,8*irrr)
     if(iaaa<0) iaaa=iaaa+8*irrr
     iaaa=iaaa+1
     iaaamax=max(iaaamax,iaaa)
     iaaamin=min(iaaamin,iaaa)
          
     error = erradar_inflate*thiserr
     errmax=max(error,errmax)
     if(thiserr>zero) errmin=min(error,errmin)
     
!    Perform limited qc based on azimuth angle, radial wind
!    speed, distance from radar site, elevation of radar,
!    height of observation, observation error, and goodness of fit to vad wind

     good0=.true.
     if(abs(azm)>r400) then
        ibadazm=ibadazm+1; good0=.false.
     end if
     if(abs(rwnd)>r200) then
        ibadwnd=ibadwnd+1; good0=.false.
     end if
     if(dist>r400) then
        ibaddist=ibaddist+1; good0=.false.
     end if
     if(staheight<-r1000.or.staheight>r50000) then
        ibadstaheight=ibadstaheight+1; good0=.false.
     end if
     if(height<-r1000.or.height>r50000) then
        ibadheight=ibadheight+1; good0=.false.
     end if
     if(height.lt.staheight) then
        iheightbelowsta=iheightbelowsta+1 ; good0=.false.
     end if
     if(thiserr>r6 .or. thiserr<=zero) then
        ibaderror=ibaderror+1; good0=.false.
     end if
     good=.true.
     if(.not.good0) then
        notgood0=notgood0+1
        cycle
     else

!       Check fit to vad wind and vad wind quality mark
        ivadz=nint(thishgt/dzvad)
        if(ivadz.gt.maxvadbins.or.ivadz.lt.1) then
           ioutofvadrange=ioutofvadrange+1
           cycle
        end if
        thiswgt=one/max(r4_single,thiserr**2)
        thisfit2=(vadu(ivad,ivadz)*cosd(azm_earth)+vadv(ivad,ivadz)*sind(azm_earth)-thisvr)**2
        thisfit=sqrt(thisfit2)
        thisvadspd=sqrt(vadu(ivad,ivadz)**2+vadv(ivad,ivadz)**2)
        vadfit2(ivad,ivadz)=vadfit2(ivad,ivadz)+thiswgt*thisfit2
        vadcount2(ivad,ivadz)=vadcount2(ivad,ivadz)+one
        vadwgt2(ivad,ivadz)=vadwgt2(ivad,ivadz)+thiswgt
        if(thisfit/max(one,thisvadspd).gt.vad_leash) then
           ibadfit=ibadfit+1; good=.false.
        end if
        if(nobs_box(irrr,iaaa,ivadz,ivad).gt.nboxmax) then
           kthin=kthin+1
           good=.false.
        end if
        if(vadqm(ivad,ivadz) > r3_5  .or.  vadqm(ivad,ivadz) < -one) then
           ibadvad=ibadvad+1 ; good=.false.
        end if
     end if
     
!    If data is good, load into output array
     if(good) then
        nsuper2_kept=nsuper2_kept+1
        level2(ivad)=level2(ivad)+1
        nobs_box(irrr,iaaa,ivadz,ivad)=nobs_box(irrr,iaaa,ivadz,ivad)+1
        ndata    =min(ndata+1,maxobs)
        nodata   =min(nodata+1,maxobs)  !number of obs not used (no meaning here)
        usage = zero
        if(icuse(ikx) < 0)usage=r100
        if(ncnumgrp(ikx) > 0 )then                     ! cross validation on
           if(mod(ndata,ncnumgrp(ikx))== ncgroup(ikx)-1)usage=ncmiter(ikx)
        end if


        cdata(1) = error             ! wind obs error (m/s)
        cdata(2) = dlon              ! grid relative longitude
        cdata(3) = dlat              ! grid relative latitude
        cdata(4) = height            ! obs absolute height (m)
        cdata(5) = rwnd              ! wind obs (m/s)
        cdata(6) = azm*deg2rad       ! azimuth angle (radians)
        cdata(7) = timeo             ! obs time (hour)
        cdata(8) = ikx               ! type               
        cdata(9) = tiltangle         ! tilt angle (radians)
        cdata(10)= staheight         ! station elevation (m)
        cdata(11)= rstation_id       ! station id
        cdata(12)= usage             ! usage parameter
        cdata(13)=dlon_earth*rad2deg ! earth relative longitude (degrees)
        cdata(14)=dlat_earth*rad2deg ! earth relative latitude (degrees)
        cdata(15)=dist               ! range from radar in km (used to estimate beam spread)
        cdata(16)=zsges              ! model elevation at radar site
        cdata(17)=thiserr

!       if(vadid(ivad).eq.'0303LWX') then
!          dist2max=max(dist2max,dist)
!          dist2min=min(dist2min,dist)
!       end if

        do i=1,maxdat
           cdata_all(i,ndata)=cdata(i)
        end do
        
     else
        notgood = notgood + 1
     end if
     
  end do


  write(6,*)'READ_RADAR:  ',trim(outmessage),' reached eof on 2/2.5/3 superob radar file'
  call closbf(lnbufr)

  write(6,*)'READ_RADAR: nsuper2_in,nsuper2_kept=',nsuper2_in,nsuper2_kept
  write(6,*)'READ_RADAR: # no vad match   =',novadmatch
  write(6,*)'READ_RADAR: # out of vadrange=',ioutofvadrange
  write(6,*)'READ_RADAR: # bad azimuths=',ibadazm
  write(6,*)'READ_RADAR: # bad winds   =',ibadwnd
  write(6,*)'READ_RADAR: # bad dists   =',ibaddist
  write(6,*)'READ_RADAR: # bad stahgts =',ibadstaheight
  write(6,*)'READ_RADAR: # bad obshgts =',ibadheight
  write(6,*)'READ_RADAR: # bad errors  =',ibaderror
  write(6,*)'READ_RADAR: # bad vadwnd  =',ibadvad
  write(6,*)'READ_RADAR: # bad fit     =',ibadfit 
  write(6,*)'READ_RADAR: # num thinned =',kthin
  write(6,*)'READ_RADAR: # notgood0    =',notgood0
  write(6,*)'READ_RADAR: # notgood     =',notgood
  write(6,*)'READ_RADAR: # hgt belowsta=',iheightbelowsta
  write(6,*)'READ_RADAR: timemin,max   =',timemin,timemax
  write(6,*)'READ_RADAR: errmin,max    =',errmin,errmax
  write(6,*)'READ_RADAR: dlatmin,max,dlonmin,max=',dlatmin,dlatmax,dlonmin,dlonmax
  write(6,*)'READ_RADAR: iaaamin,max,8*max_rrr  =',iaaamin,iaaamax,8*max_rrr


!  Next process level 2.5 and 3 superobs

!  Bigger loop over first level 2.5 data, and then level3 data

  timemax=-huge(timemax)
  timemin=huge(timemin)
  errmax=-huge(errmax)
  errmin=huge(errmin)
  nsuper2_5_in=0
  nsuper3_in=0
  nsuper2_5_kept=0
  nsuper3_kept=0
  do loop=1,2

     numhits=0
     ibadazm=izero
     ibadwnd=izero
     ibaddist=izero
     ibadheight=izero
     ibadstaheight=izero
     iheightbelowsta=izero
     ibaderror=izero
     ibadvad=0
     ibadfit=0
     ioutofvadrange=izero
     kthin=0
     novadmatch=izero
     notgood=izero
     notgood0=izero
!    dist2_5max=-huge(dist2_5max)
!    dist2_5min=huge(dist2_5min)

     if(loop.eq.1) outmessage='level 2.5 superobs:'
     if(loop.eq.2) outmessage='level 3 superobs:'

!    Open, then read bufr data
     open(lnbufr,file=infile,form='unformatted')

     call openbf(lnbufr,'IN',lnbufr)
     call datelen(10)
     call readmg(lnbufr,subset,idate,iret)
     if(iret/=0) then
        call closbf(lnbufr)
        go to 1000
     end if

     write(date,'( i10)') idate
     read (date,'(i4,3i2)') iy,im,idd,ihh 
     write(6,*)'READ_RADAR: bufr file date is ',iy,im,idd,ihh
     if(iy/=iadate(1).or.im/=iadate(2).or.idd/=iadate(3).or.&
          ihh/=iadate(4)) then
        write(6,*)'***READ_RADAR ERROR*** incompatable analysis ',&
             'and observation date/time'
        write(6,*)' year  anal/obs ',iadate(1),iy
        write(6,*)' month anal/obs ',iadate(2),im
        write(6,*)' day   anal/obs ',iadate(3),idd
        write(6,*)' hour  anal/obs ',iadate(4),ihh
        call stop2(92)
     end if

     idate5(1) = iy    ! year
     idate5(2) = im    ! month
     idate5(3) = idd   ! day
     idate5(4) = ihh   ! hour
     idate5(5) = izero ! minute
     call w3fs21(idate5,mincy)


     nmrecs=0
!    Big loop over bufr file

50   call readsb(lnbufr,iret)
60   continue
     if(iret/=0) then
        call readmg(lnbufr,subset,idate,iret)
        if(iret/=0) go to 1000
        go to 50
     end if
     if(subset.ne.subset_check(loop)) then
       iret=99
       go to 60
     end if
     nmrecs = nmrecs+1
     

!    Read header.  Extract station infomration
     call ufbint(lnbufr,hdr,10,1,levs,hdrstr)

 !   rstation_id=hdr(1)        !station id
     write(cstaid,'(2i4)')idint(hdr(1)),idint(hdr(2))
     if(cstaid(1:1).eq.' ')cstaid(1:1)='S'
     dlat_earth=hdr(1)         !station lat (degrees)
     dlon_earth=hdr(2)         !station lon (degrees)
     if (dlon_earth>=r360) dlon_earth=dlon_earth-r360
     if (dlon_earth<zero ) dlon_earth=dlon_earth+r360
     dlat_earth = dlat_earth * deg2rad
     dlon_earth = dlon_earth * deg2rad
     
     if(regional)then
        call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
        if (outside) go to 50
        dlatmax=max(dlat,dlatmax)
        dlonmax=max(dlon,dlonmax)
        dlatmin=min(dlat,dlatmin)
        dlonmin=min(dlon,dlonmin)
     else
        dlat = dlat_earth
        dlon = dlon_earth
        call grdcrd(dlat,1,rlats,nlat,1)
        call grdcrd(dlon,1,rlons,nlon,1)
     endif
     
     clon=cos(dlon_earth)
     slon=sin(dlon_earth)
     clat=cos(dlat_earth)
     slat=sin(dlat_earth)
     staheight=hdr(3)    !station elevation
     tiltangle=hdr(4)*deg2rad

!    Find vad wind match
     ivad=0
     do k=1,nvad
        cdist=sin(vadlat(k))*slat+cos(vadlat(k))*clat* &
             (sin(vadlon(k))*slon+cos(vadlon(k))*clon)
        cdist=max(-one,min(cdist,one))
        dist=acosd(cdist)
        
        if(dist < 0.2_r_kind) then
           ivad=k
           exit
        end if
     end do
     numhits(ivad)=numhits(ivad)+1
     if(ivad.eq.0) then
        novadmatch=novadmatch+1
        go to 50
     end if
     
     vadlon_earth=vadlon(ivad)
     vadlat_earth=vadlat(ivad)
     if(regional)then
        call tll2xy(vadlon_earth,vadlat_earth,dlonvad,dlatvad,outside)
        if (outside) go to 50
        dlatmax=max(dlatvad,dlatmax)
        dlonmax=max(dlonvad,dlonmax)
        dlatmin=min(dlatvad,dlatmin)
        dlonmin=min(dlonvad,dlonmin)
     else
        dlatvad = vadlat_earth
        dlonvad = vadlon_earth
        call grdcrd(dlatvad,1,rlats,nlat,1)
        call grdcrd(dlonvad,1,rlons,nlon,1)
     endif

!    Get model terrain at VAD wind location
     call deter_zsfc_model(dlatvad,dlonvad,zsges)

     iyr = hdr(5)
     imo = hdr(6)
     idy = hdr(7)
     ihr = hdr(8)
     imn = hdr(9)
     isc = izero

     idate5(1) = iyr
     idate5(2) = imo
     idate5(3) = idy
     idate5(4) = ihr
     idate5(5) = imn
     ikx=0
     do i=1,nconvtype
        if(trim(ioctype(i)) == trim(obstype))ikx = i
     end do
     if(ikx.eq.0) go to 50
     call w3fs21(idate5,minobs)
     timeb = (minobs - mincy)/r60
!    if (abs(timeb)>twind .or. abs(timeb) > ctwind(ikx)) then
     if (abs(timeb)>half .or. abs(timeb) > ctwind(ikx)) then 
!       write(6,*)'READ_RADAR:  time outside window ',timeb,' skip this obs'
        goto 50
     endif

!    Go through the data levels
     call ufbint(lnbufr,radar_obs,7,maxlevs,levs,datstr)
     if(levs>maxlevs) then
        write(6,*)'READ_RADAR:  ***ERROR*** increase read_radar bufr size since ',&
             'number of levs=',levs,' > maxlevs=',maxlevs
        call stop2(84)
     endif

     numcut=0
     do k=1,levs
        if(loop.eq.1) nsuper2_5_in=nsuper2_5_in+1
        if(loop.eq.2) nsuper3_in=nsuper3_in+1
        nread=nread+1
        timeo=(minobs+radar_obs(1,k)-mincy)/60.
        timemax=max(timemax,timeo)
        timemin=min(timemin,timeo)
        if(loop==2 .and. ivad> 0 .and. level2_5(ivad)/=0) then
           level3_tossed_by_2_5(ivad)=level3_tossed_by_2_5(ivad)+1
           numcut=numcut+1
           cycle
        end if

!       Exclude data if it does not fall within time window
        if(abs(timeo)>twind .or. abs(timeo) > ctwind(ikx)) then
!          write(6,*)'READ_RADAR:  time outside window ',timeo,&
!             ' skip obs ',nread,' at lev=',k
           cycle
        end if

!       Get observation (lon,lat).  Compute distance from radar.
        if(radar_obs(3,k)>=r360) radar_obs(3,k)=radar_obs(3,k)-r360
        if(radar_obs(3,k)<zero ) radar_obs(3,k)=radar_obs(3,k)+r360

        dlat_earth = radar_obs(2,k)*deg2rad
        dlon_earth = radar_obs(3,k)*deg2rad
        if(regional) then
           call tll2xy(dlon_earth,dlat_earth,dlon,dlat,outside)
           if (outside) cycle
        else
           dlat = dlat_earth
           dlon = dlon_earth
           call grdcrd(dlat,1,rlats,nlat,1)
           call grdcrd(dlon,1,rlons,nlon,1)
        endif
        
        clonh=cos(dlon_earth)
        slonh=sin(dlon_earth)
        clath=cos(dlat_earth)
        slath=sin(dlat_earth)
        cdist=slat*slath+clat*clath*(slon*slonh+clon*clonh)
        cdist=max(-one,min(cdist,one))
        dist=eradkm*acos(cdist)
        irrr=nint(dist*1000*xscalei)
        if(irrr<=0 .or. irrr>max_rrr) cycle

!       Set observation "type" to be function of distance from radar
        kxadd=nint(dist*one_tenth)
        kx=kx0+kxadd

!       Extract radial wind data
        height= radar_obs(4,k)
        rwnd  = radar_obs(5,k)
        azm_earth   = r90-radar_obs(6,k)
        if(regional) then
          cosazm_earth=cosd(azm_earth)
          sinazm_earth=sind(azm_earth)
          call rotate_wind_ll2xy(cosazm_earth,sinazm_earth,cosazm,sinazm,dlon_earth,dlat_earth,dlon,dlat)
          azm=atan2d(sinazm,cosazm)
        else
          azm=azm_earth
        end if
        iaaa=azm/(r360/(r8*irrr))
        iaaa=mod(iaaa,8*irrr)
        if(iaaa<0) iaaa=iaaa+8*irrr
        iaaa=iaaa+1
        iaaamax=max(iaaamax,iaaa)
        iaaamin=min(iaaamin,iaaa)
        
        error = erradar_inflate*radar_obs(7,k)
        errmax=max(error,errmax)
        if(radar_obs(7,k)>zero) errmin=min(error,errmin)
        
!       Perform limited qc based on azimuth angle, radial wind
!       speed, distance from radar site, elevation of radar,
!       height of observation, observation error.

        good0=.true.
        if(abs(azm)>r400) then
           ibadazm=ibadazm+1; good0=.false.
        end if
        if(abs(rwnd)>r200) then
           ibadwnd=ibadwnd+1; good0=.false.
        end if
        if(dist>r400) then
           ibaddist=ibaddist+1; good0=.false.
        end if
        if(staheight<-r1000 .or. staheight>r50000) then
           ibadstaheight=ibadstaheight+1; good0=.false.
        end if
        if(height<-r1000 .or. height>r50000) then
           ibadheight=ibadheight+1; good0=.false.
        end if
        if(height.lt.staheight) then
           iheightbelowsta=iheightbelowsta+1 ; good0=.false.
        end if
        if(radar_obs(7,k)>r6 .or. radar_obs(7,k)<=zero) then
           ibaderror=ibaderror+1; good0=.false.
        end if
        good=.true.
        if(.not.good0) then
           notgood0=notgood0+1
           cycle
        else

!          Check against vad wind quality mark
           ivadz=nint(height/dzvad)
           if(ivadz.gt.maxvadbins.or.ivadz.lt.1) then
              ioutofvadrange=ioutofvadrange+1
              cycle
           end if
           thiswgt=one/max(r4_single,thiserr**2)
           thisfit2=(vadu(ivad,ivadz)*cosd(azm_earth)+vadv(ivad,ivadz)*sind(azm_earth)-rwnd)**2
           thisfit=sqrt(thisfit2)
           thisvadspd=sqrt(vadu(ivad,ivadz)**2+vadv(ivad,ivadz)**2)
           if(loop.eq.1) then
              vadfit2_5(ivad,ivadz)=vadfit2_5(ivad,ivadz)+thiswgt*thisfit2
              vadcount2_5(ivad,ivadz)=vadcount2_5(ivad,ivadz)+one
              vadwgt2_5(ivad,ivadz)=vadwgt2_5(ivad,ivadz)+thiswgt
           else
              vadfit3(ivad,ivadz)=vadfit3(ivad,ivadz)+thiswgt*thisfit2
              vadcount3(ivad,ivadz)=vadcount3(ivad,ivadz)+one
              vadwgt3(ivad,ivadz)=vadwgt3(ivad,ivadz)+thiswgt
           end if
           if(thisfit/max(one,thisvadspd).gt.vad_leash) then
              ibadfit=ibadfit+1; good=.false.
           end if
           if(nobs_box(irrr,iaaa,ivadz,ivad).gt.nboxmax) then
              kthin=kthin+1
              good=.false.
           end if
           if(vadqm(ivad,ivadz)>r3_5 .or. vadqm(ivad,ivadz)<-one) then
              ibadvad=ibadvad+1 ; good=.false.
           end if
        end if

!       If data is good, load into output array
        if(good) then
           if(loop.eq.1.and.ivad.gt.0) then
              nsuper2_5_kept=nsuper2_5_kept+1
              level2_5(ivad)=level2_5(ivad)+1
           end if
           if(loop.eq.2.and.ivad.gt.0) then
              nsuper3_kept=nsuper3_kept+1
              level3(ivad)=level3(ivad)+1
           end if
           nobs_box(irrr,iaaa,ivadz,ivad)=nobs_box(irrr,iaaa,ivadz,ivad)+1
           ndata  = min(ndata+1,maxobs)
           nodata = min(nodata+1,maxobs)  !number of obs not used (no meaning here)
           usage  = zero
           if(icuse(ikx) < 0)usage=r100
           if(ncnumgrp(ikx) > 0 )then                     ! cross validation on
              if(mod(ndata,ncnumgrp(ikx))== ncgroup(ikx)-1)usage=ncmiter(ikx)
           end if
           
           
           cdata(1) = error           ! wind obs error (m/s)
           cdata(2) = dlon            ! grid relative longitude
           cdata(3) = dlat            ! grid relative latitude
           cdata(4) = height          ! obs absolute height (m)
           cdata(5) = rwnd            ! wind obs (m/s)
           cdata(6) = azm*deg2rad     ! azimuth angle (radians)
           cdata(7) = timeo           ! obs time (hour)
           cdata(8) = ikx             ! type               
           cdata(9) = tiltangle       ! tilt angle (radians)
           cdata(10)= staheight       ! station elevation (m)
           cdata(11)= rstation_id     ! station id
           cdata(12)= usage           ! usage parameter
           cdata(13)=dlon_earth*rad2deg ! earth relative longitude (degrees)
           cdata(14)=dlat_earth*rad2deg ! earth relative latitude (degrees)
           cdata(15)=dist             ! range from radar in km (used to estimate beam spread)
           cdata(16)=zsges            ! model elevation at radar site
           cdata(17)=radar_obs(7,k)   ! original error from bufr file
           
           do i=1,maxdat
              cdata_all(i,ndata)=cdata(i)
           end do
           
        else
           notgood = notgood + 1
        end if
        
!    End of k loop over levs
     end do

! End of bufr read loop
  go to 50

! Normal exit
1000 continue
  call closbf(lnbufr)


! Close unit to bufr file
  write(6,*)'READ_RADAR:  ',trim(outmessage),' reached eof on 2.5/3 superob radar file.'

  if(loop.eq.1) write(6,*)'READ_RADAR:  nsuper2_5_in,nsuper2_5_kept=',nsuper2_5_in,nsuper2_5_kept
  if(loop.eq.2) write(6,*)'READ_RADAR:  nsuper3_in,nsuper3_kept=',nsuper3_in,nsuper3_kept
  write(6,*)'READ_RADAR: # no vad match   =',novadmatch
  write(6,*)'READ_RADAR: # out of vadrange=',ioutofvadrange
  write(6,*)'READ_RADAR: # bad azimuths=',ibadazm
  write(6,*)'READ_RADAR: # bad winds   =',ibadwnd
  write(6,*)'READ_RADAR: # bad dists   =',ibaddist
  write(6,*)'READ_RADAR: # bad stahgts =',ibadstaheight
  write(6,*)'READ_RADAR: # bad obshgts =',ibadheight
  write(6,*)'READ_RADAR: # bad errors  =',ibaderror
  write(6,*)'READ_RADAR: # bad vadwnd  =',ibadvad
  write(6,*)'READ_RADAR: # bad fit     =',ibadfit 
  write(6,*)'READ_RADAR: # num thinned =',kthin
  write(6,*)'READ_RADAR: # notgood0    =',notgood0
  write(6,*)'READ_RADAR: # notgood     =',notgood
  write(6,*)'READ_RADAR: # hgt belowsta=',iheightbelowsta
  write(6,*)'READ_RADAR: timemin,max   =',timemin,timemax
  write(6,*)'READ_RADAR: errmin,max    =',errmin,errmax
  write(6,*)'READ_RADAR: dlatmin,max,dlonmin,max=',dlatmin,dlatmax,dlonmin,dlonmax
  write(6,*)'READ_RADAR: iaaamin,max,8*max_rrr  =',iaaamin,iaaamax,8*max_rrr

  end do       !   end bigger loop over first level 2.5, then level 3 radar data


! Write out vad statistics
  do ivad=1,nvad
     write(6,'(" fit of 2, 2.5, 3 data to vad station, lat, lon = ",a8,2f14.2)') &
          vadid(ivad),vadlat(ivad)*rad2deg,vadlon(ivad)*rad2deg
     do ivadz=1,maxvadbins
        if(vadcount2(ivad,ivadz).gt..5) then
           vadfit2(ivad,ivadz)=sqrt(vadfit2(ivad,ivadz)/vadwgt2(ivad,ivadz))
        else
           vadfit2(ivad,ivadz)=0
        end if
        if(vadcount2_5(ivad,ivadz).gt..5) then
           vadfit2_5(ivad,ivadz)=sqrt(vadfit2_5(ivad,ivadz)/vadwgt2_5(ivad,ivadz))
        else
           vadfit2_5(ivad,ivadz)=0
        end if
        if(vadcount3(ivad,ivadz).gt..5) then
           vadfit3(ivad,ivadz)=sqrt(vadfit3(ivad,ivadz)/vadwgt3(ivad,ivadz))
        else
           vadfit3(ivad,ivadz)=0
        end if
        write(6,'(" h,f2,f2.5,f3=",i7,f10.2,"/",i5,f10.2,"/",i5,f10.2,"/",i5)')nint(ivadz*dzvad),&
             vadfit2(ivad,ivadz),nint(vadcount2(ivad,ivadz)),&
             vadfit2_5(ivad,ivadz),nint(vadcount2_5(ivad,ivadz)),&
             vadfit3(ivad,ivadz),nint(vadcount3(ivad,ivadz))
     end do
  end do

  
! Write observation to scratch file
  write(lunout) obstype,sis,nreal,nchanl,ilat,ilon
  write(lunout) ((cdata_all(k,i),k=1,maxdat),i=1,ndata)
  deallocate(cdata_all)
  deallocate(nobs_box)
  
900 continue

  return
end subroutine read_radar

subroutine deter_zsfc_model(dlat,dlon,zsfc)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    deter_zsfc_model         determine model sfc elevation
!   prgmmr: parrish          org: np2                date: 2006-05-23
!
! abstract:  determines model sfc elevation
!
! program history log:
!   2006-05-23 parrish
!
!   input argument list:
!     dlat   - grid relative latitude
!     dlon   - grid relative longitude
!
!   output argument list:
!     zsfc     - model surface elevation (meters)
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind
  use satthin, only: zs_full
  use constants, only: zero,one
  use gridmod, only: rlats,rlons,nlat,nlon
  implicit none
  real(r_kind),intent(in) :: dlat,dlon
  real(r_kind),intent(out) :: zsfc
  integer(i_kind):: klat1,klon1,klatp1,klonp1
  real(r_kind):: dx,dy,dx1,dy1,w00,w10,w01,w11
  
  klon1=int(dlon); klat1=int(dlat)
  dx  =dlon-klon1; dy  =dlat-klat1
  dx1 =one-dx;    dy1 =one-dy
  w00=dx1*dy1; w10=dx1*dy; w01=dx*dy1; w11=dx*dy
  
  klat1=min(max(1,klat1),nlat); klon1=min(max(0,klon1),nlon)
  if(klon1==0) klon1=nlon
  klatp1=min(nlat,klat1+1); klonp1=klon1+1
  if(klonp1==nlon+1) klonp1=1

! Interpolate zsfc to obs location
  zsfc=w00*zs_full(klat1,klon1 ) + w10*zs_full(klatp1,klon1 ) + &
       w01*zs_full(klat1,klonp1) + w11*zs_full(klatp1,klonp1)
  
  return
end subroutine deter_zsfc_model
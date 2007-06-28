subroutine setupspd(lunin,mype,bwork,awork,nele,nobs,conv_diagsave,perturb)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    setupspd    compute rhs of oi for wind speed obs
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract:  For wind speed observations, this routine
!              a) reads obs assigned to given mpi task (geographic region),
!              b) simulates obs from guess,
!              c) apply some quality control to obs,
!              d) load weight and innovation arrays used in minimization
!              e) collects statistics for runtime diagnostic output
!              f) writes additional diagnostic information to output file
!
! program history log:
!   1990-10-06  parrish
!   1998-04-10  weiyu yang
!   1999-03-01  wu - ozone processing moved into setuprhs from setupoz
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   2004-06-17  treadon - update documentation
!   2004-08-02  treadon - add only to module use, add intent in/out
!   2004-10-06  parrish - increase size of vwork array for nonlinear qc
!   2004-11-22  derber - remove weight, add logical for boundary point
!   2004-12-22  treadon - move logical conv_diagsave from obsmod to argument list
!   2005-03-02  dee - remove garbage from diagnostic file
!   2005-03-09  parrish - nonlinear qc change to account for inflated obs error
!   2005-05-27  derber - level output change
!   2005-07-27  derber  - add print of monitoring and reject data
!   2005-09-28  derber  - combine with prep,spr,remove tran and clean up
!   2005-10-14  derber  - input grid location and fix regional lat/lon
!   2005-11-03  treadon - correct error in ilone,ilate data array indices
!   2005-11-29  derber - remove psfcg and use ges_lnps instead
!   2006-01-31  todling/treadon - store wgt/wgtlim in rdiagbuf(6,ii)
!   2006-02-02  treadon - rename lnprsl as ges_lnprsl
!   2006-02-08  treadon - correct vertical dimension (nsig) in call tintrp2a(ges_tv...)
!   2006-02-24  derber  - modify to take advantage of convinfo module
!   2006-03-21  treadon - add option to perturb observation
!   2006-05-30  su,derber,treadon - modify diagnostic output
!   2006-06-06  su - move to wgtlim to constants module
!   2006-07-28  derber  - modify to use new inner loop obs data structure
!                       - modify handling of multiple data at same location
!                       - unify NL qc
!   2006-07-31  kleist - use ges_ps instead of lnps
!   2006-08-28      su - fix a bug in variational qc
!
!   input argument list:
!     lunin    - unit from which to read observations
!     mype     - mpi task id
!     nele     - number of data elements per observation
!     nobs     - number of observations
!     perturb  - observation perturbation factor
!
!   output argument list:
!     bwork    - array containing information about obs-ges statistics
!     awork    - array containing information for data counts and gross checks
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,r_single,r_double,i_kind
  use obsmod, only: spdhead,spdtail,rmiss_single
  use guess_grids, only: ges_u,ges_v,nfldsig,hrdifsig,ges_tv,ges_lnprsl, &
           ges_ps,fact10,nfldsfc,hrdifsfc
  use gridmod, only: nsig,get_ij
  use qcmod, only: npres_print,ptop,pbot
  use constants, only: rad2deg,one,grav,rd,zero,four,tiny_r_kind,one_tenth, &
       half,two,cg_term,huge_single,r1000,wgtlim
  use jfunc, only: jiter,last
  use qcmod, only: dfact,dfact1,npres_print
  use convinfo, only: nconvtype,cermin,cermax,cgross,cvar_b,cvar_pg,ictype
  use convinfo, only: icsubtype
  implicit none

! Declare local variables
  real(r_kind),parameter:: ten=10.0_r_kind

! Declare passed variables
  logical,intent(in):: conv_diagsave
  integer(i_kind),intent(in):: lunin,mype,nele,nobs
  real(r_kind),dimension(100+7*nsig),intent(inout):: awork
  real(r_kind),dimension(npres_print,nconvtype,5,3),intent(inout):: bwork
  real(r_kind),dimension(nobs,2),intent(in):: perturb


! Declare local variables
  
  real(r_double) rstation_id
  
  real(r_kind) uob,vob,spdges,spdob,spdob0,goverrd,ratio_errors
  real(r_kind) presw,factw,dpres,ugesin,vgesin
  real(r_kind) dx,dy,ds,dx1,dy1,ds1,scale
  real(r_kind) val2,ressw,ress,error,ddiff,dx10,rhgh,prsfc,r0_001
  real(r_kind) sfcchk,prsln2,rwgt,tfact                        
  real(r_kind) thirty,rsig,ratio,residual,obserrlm,obserror
  real(r_kind) val,valqc,psges,drpx,dlat,dlon,dtime,dpresave,rlow
  real(r_kind) cg_spd,wgross,wnotgross,wgt,arg,exp_arg,term,rat_err2
  real(r_kind) errinv_input,errinv_adjst,errinv_final
  real(r_kind) err_input,err_adjst,err_final
  real(r_kind),dimension(nele,nobs):: data
  real(r_kind),dimension(nobs):: dup
  real(r_kind),dimension(nsig)::prsltmp,tges
  real(r_single),allocatable,dimension(:,:)::rdiagbuf

  integer(i_kind) jlat,jlon,jsig,mm1,itype
  integer(i_kind) ii,i,nchar,nreal,k,j,n,l,it,nty,nn,ikxx
  integer(i_kind) ier,ilon,ilat,ipres,iuob,ivob,id,itime,ikx
  integer(i_kind) ihgt,iqc,ier2,iuse,ilate,ilone,istnelv,istat

  
  logical,dimension(nobs):: luse,muse

  character(8) station_id
  character(8),allocatable,dimension(:):: cdiagbuf

  equivalence(rstation_id,station_id)


!******************************************************************************
! Read and reformat observations in work arrays.
  read(lunin)data,luse

!        index information for data array (see reading routine)
  ier=1       ! index of obs error
  ilon=2      ! index of grid relative obs location (x)
  ilat=3      ! index of grid relative obs location (y)
  ipres=4     ! index of pressure
  iuob=5      ! index of u observation
  ivob=6      ! index of v observation
  id=7        ! index of station id
  itime=8     ! index of observation time in data array
  ikxx=9      ! index of ob type
  ihgt=10     ! index of observation elevation
  iqc=11      ! index of quality mark
  ier2=12     ! index of original-original obs error ratio
  iuse=13     ! index of use parameter
  ilone=14    ! index of longitude (degrees)
  ilate=15    ! index of latitude (degrees)
  istnelv=16  ! index of station elevation (m)

  mm1=mype+1
  scale=one
  rsig=nsig
  thirty = 30.0_r_kind
  r0_001=0.001_r_kind
  goverrd=grav/rd
  

! If requested, save select data for output to diagnostic file
  if(conv_diagsave)then
     ii=0
     nchar=1
     nreal=20
     allocate(cdiagbuf(nobs),rdiagbuf(nreal,nobs))
  end if


  do i=1,nobs
    muse(i)=nint(data(iuse,i)) <= jiter
  end do

  dup=one
  do k=1,nobs
     do l=k+1,nobs
        if(data(ilat,k) == data(ilat,l) .and.  &
           data(ilon,k) == data(ilon,l) .and.  &
           data(ipres,k)== data(ipres,l) .and. &
           data(ier,k) < r1000 .and. data(ier,l) < r1000 .and. &
           muse(l) .and. muse(k))then

          tfact=min(one,abs(data(itime,k)-data(itime,l))/dfact1)
          dup(k)=dup(k)+one-tfact*tfact*(one-dfact)
          dup(l)=dup(l)+one-tfact*tfact*(one-dfact)
        end if
     end do
  end do

  do i=1,nobs

    dlat=data(ilat,i)
    dlon=data(ilon,i)
    dtime=data(itime,i)
    dpres=data(ipres,i)
    error=data(ier2,i)
    ikx=nint(data(ikxx,i))


!   Perturb observation.  Note:  if perturb_obs=.false., the
!   array perturb=0.0 and observation is unchanged.
    obserror = max(cermin(ikx),min(cermax(ikx),data(ier,i)))
    uob = data(iuob,i) + perturb(i,1)*obserror
    vob = data(ivob,i) + perturb(i,2)*obserror

 
    spdob=sqrt(uob*uob+vob*vob)
    call tintrp2a(ges_tv,tges,dlat,dlon,dtime,hrdifsig,&
         1,nsig,mype,nfldsig)
    call tintrp2a(fact10,factw,dlat,dlon,dtime,hrdifsfc,&
         1,1,mype,nfldsfc)
    call tintrp2a(ges_ps,psges,dlat,dlon,dtime,hrdifsig,&
         1,1,mype,nfldsig)
    call tintrp2a(ges_lnprsl,prsltmp,dlat,dlon,dtime,hrdifsig,&
         1,nsig,mype,nfldsig)

    presw = ten*exp(dpres)
    dpres = dpres-log(psges)
    nty=ictype(ikx)
    drpx=zero
    if(nty >= 280 .and. nty < 290)then
        dpresave=dpres
        dpres=-goverrd*data(ihgt,i)/tges(1)
        if(nty < 283)drpx=abs(dpres-dpresave)*factw*thirty
    end if

    prsfc=psges
    prsln2=log(exp(prsltmp(1))/prsfc)
    sfcchk=log(psges)
    if(dpres <= prsln2)then
        factw=one
    else
        dx10=-goverrd*ten/tges(1)
        if (dpres < dx10)then
           factw=(dpres-dx10+factw*(prsln2-dpres))/(prsln2-dx10)
        end if
    end if

!   Put obs pressure in correct units to get grid coord. number
    dpres=log(exp(dpres)*prsfc)
    call grdcrd(dpres,1,prsltmp(1),nsig,-1)

!    Get approx k value of sfc by using surface pressure of 1st ob
    call grdcrd(sfcchk,1,prsltmp(1),nsig,-1)


!   Check to see if observations is below what is seen to be the surface
    rlow=max(sfcchk-dpres,zero)

    rhgh=max(dpres-r0_001-rsig,zero)

    if(luse(i))then
       awork(1) = awork(1) + one
       if(rlow/=zero) awork(2) = awork(2) + one
       if(rhgh/=zero) awork(3) = awork(3) + one
    end if

    ratio_errors=error/((data(ier,i)+drpx+1.0e6*rhgh+four*rlow)*sqrt(dup(i)))

    error=one/error

!   Check to see if observations is above the top of the model (regional mode)
    if (dpres>rsig) ratio_errors=zero


! Interpolate guess u and v to observation location and time.
    call tintrp3(ges_u,ugesin,dlat,dlon,dpres,dtime, &
       hrdifsig,1,mype,nfldsig)
    call tintrp3(ges_v,vgesin,dlat,dlon,dpres,dtime, &
       hrdifsig,1,mype,nfldsig)


! Apply 10-meter wind reduction factor to guess winds.  Compute
! guess wind speed.
     ugesin=factw*ugesin
     vgesin=factw*vgesin
     spdges=sqrt(ugesin*ugesin+vgesin*vgesin)
     ddiff = spdob-spdges

!    Gross error checks
     obserror = one/max(ratio_errors*error,tiny_r_kind)
     obserrlm = max(cermin(ikx),min(cermax(ikx),obserror))
     residual = abs(ddiff)
     ratio    = residual/obserrlm
     if (ratio>cgross(ikx) .or. ratio_errors < tiny_r_kind) then
        if (luse(i)) awork(4) = awork(4)+one
        error = zero
        ratio_errors = zero
        muse(i)=.false.
     end if

     if (ratio_errors*error <=tiny_r_kind) muse(i)=.false.

!    Compute penalty terms (linear & nonlinear qc).
     val      = error*ddiff
     val2     = val*val
     exp_arg  = -half*val2
     rat_err2 = ratio_errors**2
     if (cvar_pg(ikx) > tiny_r_kind .and. error > tiny_r_kind) then
        arg  = exp(exp_arg)
        wnotgross= one-cvar_pg(ikx)
        cg_spd=cvar_b(ikx)
        wgross = cg_term*cvar_pg(ikx)/(cg_spd*wnotgross)
        term = log((arg+wgross)/(one+wgross))
        wgt  = one-wgross/(arg+wgross)
        wgt  = wgt/wgtlim
     else
        term = exp_arg
        wgt  = wgtlim
        rwgt = wgt/wgtlim
     endif
     valqc = -two*rat_err2*term


!       Accumulate statistics for obs belonging to this task
     if (luse(i) .and. muse(i)) then
          if(rwgt < one) awork(61) = awork(61)+one
          awork(5)=awork(5) + val2*rat_err2
          awork(6)=awork(6) + one
          awork(22)=awork(22) + valqc
     end if

! Loop over pressure level groupings and obs to accumulate statistics
! as a function of observation type.
     do k = 1,npres_print
       if(luse(i) .and.presw >=ptop(k) .and. presw<=pbot(k))then
        ress  = scale*ddiff
        ressw = ress*ress
        nn=1
        if (.not. muse(i)) then
          nn=2
          if(ratio_errors*error >=tiny_r_kind)nn=3
        end if
        bwork(k,ikx,1,nn) = bwork(k,ikx,1,nn)+one            ! count
        bwork(k,ikx,2,nn) = bwork(k,ikx,2,nn)+ddiff          ! bias
        bwork(k,ikx,3,nn) = bwork(k,ikx,3,nn)+ressw          ! (o-g)**2
        bwork(k,ikx,4,nn) = bwork(k,ikx,4,nn)+val2*rat_err2  ! penalty
        bwork(k,ikx,5,nn) = bwork(k,ikx,5,nn)+valqc          ! nonlin qc penalty

       end if
     end do
!    If obs is "acceptable", load array with obs info for use
!    in inner loop minimization (int* and stp* routines)
     if (.not. last .and. muse(i)) then

        if(.not. associated(spdhead))then
            allocate(spdhead,stat=istat)
            if(istat /= 0)write(6,*)' failure to write spdhead '
            spdtail => spdhead
        else
            allocate(spdtail%llpoint,stat=istat)
            spdtail => spdtail%llpoint
            if(istat /= 0)write(6,*)' failure to write spdtail%llpoint '
        end if

!       Set (i,j) indices of guess gridpoint that bound obs location
        call get_ij(mm1,dlat,dlon,spdtail%ij(1),spdtail%wij(1))

        do j=1,4
           spdtail%wij(j)=factw*spdtail%wij(j)
        end do
        spdtail%raterr2= ratio_errors**2     
        spdtail%res    = spdob
        spdtail%uges   = ugesin
        spdtail%vges   = vgesin
        spdtail%err2   = error**2
        spdtail%time   = dtime
        spdtail%luse   = luse(i)
        spdtail%b      = cvar_b(ikx)
        spdtail%pg     = cvar_pg(ikx)

     end if
! Save select output for diagnostic file
     if(conv_diagsave .and. luse(i))then
        ii=ii+1
        rstation_id     = data(id,i)
        cdiagbuf(ii)    = station_id         ! station id

        rdiagbuf(1,ii)  = ictype(ikx)        ! observation type
        rdiagbuf(2,ii)  = icsubtype(ikx)     ! observation subtype
    
        rdiagbuf(3,ii)  = data(ilate,i)      ! observation latitude (degrees)
        rdiagbuf(4,ii)  = data(ilone,i)      ! observation longitude (degrees)
        rdiagbuf(5,ii)  = data(istnelv,i)    ! station elevation (meters)
        rdiagbuf(6,ii)  = presw              ! observation pressure (hPa)
        rdiagbuf(7,ii)  = data(ihgt,i)       ! observation height (meters)
        rdiagbuf(8,ii)  = dtime              ! obs time (hours relative to analysis time)

        rdiagbuf(9,ii)  = data(iqc,i)        ! input prepbufr qc or event mark
        rdiagbuf(10,ii) = rmiss_single       ! setup qc or event mark
        rdiagbuf(11,ii) = data(iuse,i)       ! read_prepbufr data usage flag
        if(muse(i)) then
           rdiagbuf(12,ii) = one             ! analysis usage flag (1=use, -1=not used)
        else
           rdiagbuf(12,ii) = -one
        endif

        spdob0    = sqrt(data(iuob,i)*data(iuob,i)+data(ivob,i)*data(ivob,i))
        err_input = data(ier2,i)
        err_adjst = data(ier,i)
        if (ratio_errors*error>tiny_r_kind) then
           err_final = one/(ratio_errors*error)
        else
           err_final = huge_single
        endif

        errinv_input = huge_single
        errinv_adjst = huge_single
        errinv_final = huge_single
        if (err_input>tiny_r_kind) errinv_input = one/err_input
        if (err_adjst>tiny_r_kind) errinv_adjst = one/err_adjst
        if (err_final>tiny_r_kind) errinv_final = one/err_final

        rdiagbuf(13,ii) = rwgt               ! nonlinear qc relative weight
        rdiagbuf(14,ii) = errinv_input       ! prepbufr inverse obs error (m/s)**-1
        rdiagbuf(15,ii) = errinv_adjst       ! read_prepbufr inverse obs error (m/s)**-1
        rdiagbuf(16,ii) = errinv_final       ! final inverse observation error (m/s)**-1

        rdiagbuf(17,ii) = spdob              ! wind speed observation (m/s)
        rdiagbuf(18,ii) = ddiff              ! obs-ges used in analysis (m/s)
        rdiagbuf(19,ii) = spdob0-spdges      ! obs-ges w/o bias correction (m/s) (future slot)

        rdiagbuf(20,ii) = factw              ! 10m wind reduction factor


     end if
  end do

! Write information to diagnostic file
  if(conv_diagsave)then
     write(7)'spd',nchar,nreal,ii,mype
     write(7)cdiagbuf(1:ii),rdiagbuf(:,1:ii)
     deallocate(cdiagbuf,rdiagbuf)
  end if

! End of routine
end subroutine setupspd
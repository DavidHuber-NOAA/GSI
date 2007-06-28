subroutine qcssmi(nchanl,   &
     sfchgt,luse,sea,land,ice,snow,mixed, &
     ts,pems,ierrret,kraintype,tpwc,clw,sgagl,    &
     tbcnob,ssmi,amsre_low,amsre_mid,amsre_hig,ssmis, &
     varinv,errf,aivals,id_qc )

! subprogram:  qcssmi      QC for ssmi/amsre
! prgmmr: okamoto          org: np23            date: 2004-12-01
!
! abstract: set quality control criteria for SSM/I,AMSR-E
!
! program history log:
!     2004-12-01  okamoto 
!     2005-02-17  derber  clean up surface flags
!     2005-03-04  treadon  - correct underflow error for varinv
!     2005-09-05  derber - allow max error to change by channel
!     2005-10-07  Xu & Pawlak - add SSMIS qc code, add documentation
!     2005-10-20  kazumori - add AMSR-E qc code, add documentation
!     2006-02-03  derber  - modify for new obs control and stats         
!     2006-04-26  kazumori  - change clw theshold for AMSR-E
!     2006-04-27  derber - modify to do single profile - fix bug
!     2006-07-27  kazumori - modify AMSR-E qc and input of the subroutine
!     2006-12-01  derber - modify id_qc flags
! 
! input argument list:
!     nchanl  - number of channels per obs
!     sfchgt  - surface height (not use now)
!     luse    - logical use flag
!     sea     - logical, sea flag
!     land    - logical, land flag
!     ice     - logical, ice flag
!     snow    - logical, snow flag
!     mixed   - logical, mixed zone flag
!     ts      - skin temperature
!     pems    - surface emissivity
!     ierrret - result flag of retrieval_mi
!     kraintype - [0]no rain, [others]rain ; see retrieval_mi
!     clw     - retrieve clw [kg/m2]
!     sgagl   - sun glint angle [degrees]
!     tpwc    - retrieve tpw [kg/m2]
!     tbcnob  - Obs - Back TBB without bias correction
!     ssmi    - logical true if ssmi is processed 
!     ssmis    - logical true if ssmis is processed 
!     amsre_low   - logical true if amsre_low is processed 
!     amsre_mid   - logical true if amsre_mid is processed 
!     amsre_hig   - logical true if amsre_hig is processed 
!
! NOTE! if retrieved clw/tpwc not available over ocean,set -9.99e+11, 
!       but 0 over land/mixed/ice
!
! output argument list:
!     varinv  - observation weight (modified obs var error inverse)
!     errf    - criteria of gross error
!     aivals  - number of data not passing QC
!     id_qc   - qc index, common to all ch
!
! Special Notes:
!     id_qc is used for tracing each QC
!         0:use
!         2:land/ice/snow, 3:sfchgt>2000, 4:rain 5:retrieval_mi error, 6:clw
!         7:sgagl, 9: amsre dtb 10:clwch, 11:term, 12:gross error,  
!     When several QC criteria are satisfied, the first QC goes to id_qc 
!
!
!     ... possibe QC to add ..........................
!     * decrease varinv at last several scan position
!  
!     clwcutofx is used to set cloud qc threshold  (kg/m2) 
!     from Fuzhong Weng (need better reference) 
!     ................................................
!
! attributes:
!     language: f90
!     machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind, i_kind
  use constants, only: one,izero,zero,tiny_r_kind
  implicit none


! Declare passed variables
  integer(i_kind),intent(in) :: nchanl
  integer(i_kind),intent(in):: kraintype,ierrret
  integer(i_kind),dimension(nchanl),intent(inout):: id_qc

  logical,intent(in):: sea,snow,land,ice,mixed,luse
  logical,intent(in):: ssmi,amsre_low,amsre_mid,amsre_hig,ssmis

  real(r_kind),intent(in):: sfchgt,tpwc,clw,sgagl
  real(r_kind),dimension(nchanl),intent(in):: ts,pems
  real(r_kind),dimension(nchanl),intent(in):: tbcnob

  real(r_kind),dimension(nchanl),intent(inout):: varinv,errf
  real(r_kind),dimension(40),intent(inout):: aivals

! Declare local variables
  integer(i_kind) :: n,ll,l,m,i
  real(r_kind) :: efact,vfact,dtempf,fact,dtbf,dtbf2,chdiff,term
  real(r_kind),dimension(nchanl) :: demisf_mi,clwcutofx 
  real(r_kind),parameter:: r2000=2000.0_r_kind

!------------------------------------------------------------------
! Set cloud qc criteria  (kg/m2) :  reject when clw>clwcutofx
  if(ssmi) then
     clwcutofx(1:nchanl) =  &  
          (/0.35_r_kind, 0.35_r_kind, 0.27_r_kind, 0.10_r_kind, &
          0.10_r_kind, 0.024_r_kind, 0.024_r_kind/) 
  else if(amsre_low.or.amsre_mid.or.amsre_hig) then
     clwcutofx(1:nchanl) =  &  
          (/0.350_r_kind, 0.350_r_kind, 0.350_r_kind, 0.350_r_kind, &
          0.300_r_kind, 0.300_r_kind, 0.250_r_kind, 0.250_r_kind, &
          0.100_r_kind, 0.100_r_kind, 0.020_r_kind, 0.020_r_kind/) 
!    --- amsre separate channel treatment depend on FOV
     if(amsre_low) varinv(5:12)=zero
     if(amsre_mid) varinv(1:4)=zero
     if(amsre_mid) varinv(11:12)=zero
     if(amsre_hig) varinv(1:10)=zero
  else if(ssmis) then
     clwcutofx(1:nchanl) =  &  !kg/m2  reject when clw>clwcutofx
          (/ (0.10_r_kind*i,i=1,11), 0.35_r_kind, 0.35_r_kind, &
          0.27_r_kind, 0.10_r_kind, 0.10_r_kind, 0.022_r_kind, &
          0.022_r_kind, (10.0_r_kind*i,i=1,6)  /)
  end if
  dtempf = 0.5_r_kind
  demisf_mi(1:nchanl) = 0.01_r_kind

! Loop over observations.

  efact     =one
  vfact     =one
! id_qc = 1           do not use (from setuprad)
! id_qc = 2           not sea
! id_qc = 3           high topography
! id_qc = 4           kraintype /=izero
! id_qc = 5           ierrret > izero
! id_qc = 6           tpwc <=zero
! id_qc = 7           sgagl < 25. and amsre_low
! id_qc = 8           gross check (later in setuprad)
! id_qc = 9           amsre dtb threshold of an inaccuracy of emis model
! id_qc = 10          first channel with clw > cutoff
! id_qc = 11          gross error

!    Over sea               
  if(sea) then 

!    dtb/rain/clw qc using SSM/I RAYTHEON algorithm
     if( ierrret>izero  .or. kraintype/=izero .or. tpwc<=zero ) then 
        efact=zero; vfact=zero
        if(luse) aivals(8) = aivals(8) + one
           
        if(luse)then
           do i=1,nchanl
             if( id_qc(i)==izero .and. kraintype/=izero ) id_qc(i)=4
             if( id_qc(i)==izero .and. ierrret>izero )    id_qc(i)=5
             if( id_qc(i)==izero .and. tpwc<=zero )       id_qc(i)=6
           end do 
        end if
     else if(amsre_low .and. sgagl < 25.0_r_kind) then

! ---- sun glint angle qc (for AMSR-E)

         varinv(1:4)=zero
         do i=1,4
           if(id_qc(i) == izero)id_qc(i) = 7
         end do
         if(luse) aivals(11) = aivals(11) + one

     else if(amsre_low .or. amsre_mid .or. amsre_hig)then

! ---- dtb threshold qc for AMSR-E due to an inaccuracy of emis model

       if( abs(tbcnob(1)) > 6.0_r_kind .or. &
           abs(tbcnob(2)) > 6.0_r_kind .or. &
           abs(tbcnob(3)) > 6.0_r_kind .or. &
           abs(tbcnob(4)) > 6.0_r_kind .or. &
           abs(tbcnob(5)) > 6.0_r_kind .or. &
           abs(tbcnob(6)) > 8.0_r_kind .or. &
           abs(tbcnob(7)) > 8.0_r_kind .or. &
           abs(tbcnob(8)) > 10.0_r_kind .or. &
           abs(tbcnob(9)) > 6.0_r_kind .or. &
           abs(tbcnob(10)) > 6.0_r_kind) then
           varinv(:)=zero
           do i=1,nchanl
             id_qc(i)=9
           end do
         if(luse) aivals(13) = aivals(13) + one
       end if

     else if(clw > zero)then

!      If dtb is larger than demissivity and dwmin contribution, 
!      it is assmued to be affected by  rain and cloud, tossing it out
       do l=1,nchanl

!          clw QC using ch-dependent threshold (clwch)
         if( clw > clwcutofx(l) ) then
           varinv(l)=zero
           if(luse) then
             aivals(10) = aivals(10) + one
             if(id_qc(l)==izero) then
               id_qc(l)=10
               aivals(9)=aivals(9) + one
             end if
           end if
         end if
       end do  !l_loop
     end if

!    Use only data over sea
  else  !land,sea ice,mixed

!   Reduce q.c. bounds over higher topography

     if (sfchgt > r2000) then
       fact = r2000/sfchgt
       efact = fact*efact
       vfact = fact*vfact
       do i=1,nchanl
         if(id_qc(i)==izero.and.luse) id_qc(i)=3
       end do
     end if

!    demisf_mi=demisf_mi*0.7_r_kind   ! not necessary since data not used
     efact=zero
     vfact=zero
     do i=1,nchanl
       if(id_qc(i)==izero.and.luse) id_qc(i)=2
     end do
  end if


! Generate q.c. bounds and modified variances.
  do l=1,nchanl

     errf(l)   = efact*errf(l)
     varinv(l) = vfact*varinv(l)
     
     if (varinv(l) > tiny_r_kind) then
        dtbf = demisf_mi(l)*abs(pems(l)) + dtempf*abs(ts(l))
        term = dtbf*dtbf
        if(term>tiny_r_kind) varinv(l)=one/(one/varinv(l)+term)
     else if(luse  .and. id_qc(l)==izero )then
        id_qc(l)=11
     endif
        

  end do ! l (ch) loop end
      

  return
end subroutine qcssmi
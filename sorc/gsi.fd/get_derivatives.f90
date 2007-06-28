subroutine get_derivatives(u,v,t,p,q,oz,skint,cwmr, &
                 u_x,v_x,t_x,p_x,q_x,oz_x,skint_x,cwmr_x, &
                 u_y,v_y,t_y,p_y,q_y,oz_y,skint_y,cwmr_y, &
                 nlevs,mype,nfldsig)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    get_derivatives  compute horizontal derivatives
!   prgmmr: parrish          org: np22                date: 2005-06-06
!
! abstract: get horizontal derivatives of state vector
!
! program history log:
!   2005-06-06  parrish
!   2005=07-10  kleist, clean up and fix skint
!
!   input argument list:
!     u        - longitude velocity component
!     v        - latitude velocity component
!     t        - virtual temperature
!     p        - ln(psfc)
!     q        - moisture
!     oz       - ozone
!     skint    - skin temperature
!     cwmr     - cloud water mixing ratio
!     nlevs    - number of levs on current processor in horizontal slab mode
!     mype     - current processor number
!     nfldsig  - number of time levels
!
!   output argument list:
!     u_x      - longitude derivative of u  (note: in global mode, undefined at pole points)
!     v_x      - longitude derivative of v  (note: in global mode, undefined at pole points)
!     t_x      - longitude derivative of t
!     p_x      - longitude derivative of ln(psfc)
!     q_x      - longitude derivative of moisture
!     oz_x     - longitude derivative of ozone
!     skint_x  - longitude derivative of skin temperature
!     cwmr_x   - longitude derivative of cwmr
!     u_y      - latitude derivative of u  (note: in global mode, undefined at pole points)
!     v_y      - latitude derivative of v  (note: in global mode, undefined at pole points)
!     t_y      - latitude derivative of t
!     p_y      - latitude derivative of ln(psfc)
!     q_y      - latitude derivative of moisture
!     oz_y     - latitude derivative of ozone
!     skint_y  - latitude derivative of skin temperature
!     cwmr_y   - latitude derivative of cwmr
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
!   note:  u_x,v_x,u_y,v_y are not evaluated at the poles
!     all other derivatives are

!   for u and v, derivatives are following:

!     u_x:  (du/dlon)/(a*cos(lat))
!     u_y:  (d(u*cos(lat))/dlat)/(a*cos(lat))

!     v_x:  (dv/dlon)/(a*cos(lat))
!     v_y:  (d(v*cos(lat))/dlat)/(a*cos(lat))

!  for all other variables, derivatives are:

!     f_x:  (df/dlon)/(a*cos(lat))
!     f_y:  (df/dlat)/a

  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: regional,nlat,nlon,lat2,lon2,nsig,nsig1o
  use compact_diffs, only: compact_dlat,compact_dlon
  use mpimod, only: npe,nvar_id

  implicit none

! Passed variables
  integer(i_kind) mype
  integer(i_kind) nlevs,nfldsig
  real(r_kind),dimension(lat2,lon2,nfldsig),intent(in):: p,skint
  real(r_kind),dimension(lat2,lon2,nsig,nfldsig),intent(in):: t,q,cwmr,oz,u,v
  real(r_kind),dimension(lat2,lon2,nfldsig),intent(out):: p_x,skint_x
  real(r_kind),dimension(lat2,lon2,nsig,nfldsig),intent(out):: t_x,q_x,cwmr_x,oz_x,u_x,v_x
  real(r_kind),dimension(lat2,lon2,nfldsig),intent(out):: p_y,skint_y
  real(r_kind),dimension(lat2,lon2,nsig,nfldsig),intent(out):: t_y,q_y,cwmr_y,oz_y,u_y,v_y

! Local Variables
  integer(i_kind) iflg,k,i,j,nbad,it
  real(r_kind),dimension(lat2,lon2):: slndt,sicet
  real(r_kind),dimension(lat2,lon2):: slndt_x,sicet_x
  real(r_kind),dimension(lat2,lon2):: slndt_y,sicet_y
  real(r_kind),dimension(nlat,nlon,nsig1o):: hwork,hworkd
  logical vector

  iflg=1
  slndt=zero
  sicet=zero

  if(nsig1o > nlevs)then
    do k=nlevs+1,nsig1o
      do j=1,nlon
        do i=1,nlat
          hworkd(i,j,k) = zero
        end do
      end do
    end do
  end if

  do it=1,nfldsig
    call sub2grid(hwork,t(1,1,1,it),p(1,1,it),q(1,1,1,it),oz(1,1,1,it), &
                  skint(1,1,it),slndt,sicet,cwmr(1,1,1,it),u(1,1,1,it), &
                  v(1,1,1,it),iflg)


!   x derivative
    do k=1,nlevs
      if(regional) then
        call get_dlon_reg(hwork(1,1,k),hworkd(1,1,k))
      else
        vector = nvar_id(k) == 1 .or. nvar_id(k) == 2
        call compact_dlon(hwork(1,1,k),hworkd(1,1,k),vector)
      end if
    end do
    call grid2sub(hworkd,t_x(1,1,1,it),p_x(1,1,it),q_x(1,1,1,it), &
                  oz_x(1,1,1,it),skint_x(1,1,it),slndt_x,sicet_x, &
                  cwmr_x(1,1,1,it),u_x(1,1,1,it),v_x(1,1,1,it))

!   y derivative
    do k=1,nsig1o
      if(regional) then
        call get_dlat_reg(hwork(1,1,k),hworkd(1,1,k))
      else
        vector = nvar_id(k) == 1 .or. nvar_id(k) == 2
        call compact_dlat(hwork(1,1,k),hworkd(1,1,k),vector)
      end if
    end do
    call grid2sub(hworkd,t_y(1,1,1,it),p_y(1,1,it),q_y(1,1,1,it), &
                  oz_y(1,1,1,it),skint_y(1,1,it),slndt_y,sicet_y, &
                  cwmr_y(1,1,1,it),u_y(1,1,1,it),v_y(1,1,1,it))
  end do  ! end do it

  return
end subroutine get_derivatives

subroutine tget_derivatives(u,v,t,p,q,oz,skint,cwmr, &
                 u_x,v_x,t_x,p_x,q_x,oz_x,skint_x,cwmr_x, &
                 u_y,v_y,t_y,p_y,q_y,oz_y,skint_y,cwmr_y,nlevs,mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tget_derivatives  adjoint of get_derivatives
!   prgmmr: parrish          org: np22                date: 2005-06-06
!
! abstract: adjoint of get_derivatives 
!
! program history log:
!   2005-06-06  parrish
!   2005-07-10  kleist, clean up
!
!   input argument list:
!     u_x      - longitude derivative of u  (note: in global mode, undefined at pole points)
!     v_x      - longitude derivative of v  (note: in global mode, undefined at pole points)
!     t_x      - longitude derivative of t
!     p_x      - longitude derivative of ln(psfc)
!     q_x      - longitude derivative of moisture
!     oz_x     - longitude derivative of ozone
!     skint_x  - longitude derivative of skin temperature
!     cwmr_x   - longitude derivative of cwmr
!     u_y      - latitude derivative of u  (note: in global mode, undefined at pole points)
!     v_x      - latitude derivative of v  (note: in global mode, undefined at pole points)
!     t_y      - latitude derivative of t
!     p_y      - latitude derivative of ln(psfc)
!     q_y      - latitude derivative of moisture
!     oz_y     - latitude derivative of ozone
!     skint_y  - latitude derivative of skin temperature
!     cwmr_y   - latitude derivative of cwmr
!     nlevs    - number of levs on current processor in horizontal slab mode
!     mype     - current processor number
!
!   output argument list:
!     u        - longitude velocity component
!     v        - latitude velocity component
!     t        - virtual temperature
!     p        - ln(psfc)
!     q        - moisture
!     oz       - ozone
!     skint    - skin temperature
!     cwmr     - cloud water mixing ratio
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
!    adjoint of get_derivatives

  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: regional,nlat,nlon,lat2,lon2,nsig,nsig1o
  use compact_diffs, only: tcompact_dlat,tcompact_dlon
  use mpimod, only: npe,nvar_id
  implicit none

! Passed variables
  integer(i_kind) mype
  integer(i_kind) nlevs
  real(r_kind),dimension(lat2,lon2),intent(inout):: p,skint
  real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t,q,cwmr,oz,u,v
  real(r_kind),dimension(lat2,lon2),intent(inout):: p_x,skint_x
  real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t_x,q_x,cwmr_x,oz_x,u_x,v_x
  real(r_kind),dimension(lat2,lon2),intent(inout):: p_y,skint_y
  real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t_y,q_y,cwmr_y,oz_y,u_y,v_y

! Local Variables
  integer(i_kind) iflg,k,i,j,nbad
  real(r_kind),dimension(lat2,lon2):: slndt,sicet
  real(r_kind),dimension(lat2,lon2):: slndt_x,sicet_x
  real(r_kind),dimension(lat2,lon2):: slndt_y,sicet_y
  real(r_kind),dimension(nlat,nlon,nsig1o):: hwork,hworkd
  logical vector

  iflg=1
!             initialize hwork to zero, so can accumulate contribution from
!             all derivatives
  hwork=zero
!             for now zero out slndt,sicet
  slndt_x=zero
  sicet_x=zero
  slndt_y=zero
  sicet_y=zero

!   adjoint of y derivative

  call sub2grid(hworkd,t_y,p_y,q_y,oz_y,skint_y,slndt_y,sicet_y,cwmr_y, &
                u_y,v_y,iflg)
  do k=1,nlevs
    if(regional) then
      call tget_dlat_reg(hworkd(1,1,k),hwork(1,1,k))
    else
      vector = nvar_id(k) == 1 .or. nvar_id(k) == 2
      call tcompact_dlat(hwork(1,1,k),hworkd(1,1,k),vector)
    end if
  end do

!   adjoint of x derivative

  call sub2grid(hworkd,t_x,p_x,q_x,oz_x,skint_x,slndt_x,sicet_x,cwmr_x, &
                u_x,v_x,iflg)
  do k=1,nlevs
    if(regional) then
      call tget_dlon_reg(hworkd(1,1,k),hwork(1,1,k))
    else
      vector = nvar_id(k) == 1 .or. nvar_id(k) == 2
      call tcompact_dlon(hwork(1,1,k),hworkd(1,1,k),vector)
    end if
  end do


!       use t_x,etc since don't need to save contents
  call grid2sub(hwork,t_x,p_x,q_x,oz_x,skint_x,slndt_x,sicet_x,cwmr_x,u_x,v_x)

!   accumulate to contents of t,p,etc (except st,vp, which are zero on input
  do k=1,nsig
    do j=1,lon2
      do i=1,lat2
        t(i,j,k)=t(i,j,k)+t_x(i,j,k)
        q(i,j,k)=q(i,j,k)+q_x(i,j,k)
        u(i,j,k)=u(i,j,k)+u_x(i,j,k)
        v(i,j,k)=v(i,j,k)+v_x(i,j,k)
        oz(i,j,k)=oz(i,j,k)+oz_x(i,j,k)
        cwmr(i,j,k)=cwmr(i,j,k)+cwmr_x(i,j,k)
      end do
    end do
  end do
  do j=1,lon2
    do i=1,lat2
      p(i,j)=p(i,j)+p_x(i,j)
      skint(i,j)=skint(i,j)+skint_x(i,j)
    end do
  end do

end subroutine tget_derivatives


subroutine get_zderivs(z,z_x,z_y,mype,nfldsig)
! $$
! subprogram:    get_zderivs    get derivatives of terrain
!   prgmmr: parrish          org: np22                date: 2005-09-29
!
! abstract: get derivatives od terrain field
!
! program history log:
!   2005-09-29  parrish
!   2005-12-05  todling - reorder passed variable declarations
!
!   input argument list:
!     z         - terrain grid
!     mype      - integer task id
!     nfldsig   - number of time periods in terrain grid array
!
!   output argument list:
!     z_x       - zonal derivative of terrain field
!     z_y       - meridional derivative of terrain field
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use gridmod, only: regional,nlat,nlon,lat2,lon2,nsig,lat1,lon1,&
     displs_s,ltosj_s,ijn_s,ltosi,ltosj,iglobal,ltosi_s,itotsub,&
     ijn,displs_g
  use compact_diffs, only: compact_dlat,compact_dlon
  use mpimod, only: mpi_comm_world,ierror,mpi_rtype,strip
  implicit none

! Passed variables
  integer(i_kind),intent(in):: mype,nfldsig
  real(r_kind),dimension(lat2,lon2,nfldsig),intent(in):: z
  real(r_kind),dimension(lat2,lon2,nfldsig),intent(out):: z_x,z_y

! Local variables
  real(r_kind),dimension(lat1*lon1):: zsm
  real(r_kind),dimension(itotsub):: work1
  real(r_kind),dimension(nlat,nlon):: workh,workd
  real(r_kind),dimension(lat2,lon2):: ztmp
  integer(i_kind) mm1,i,j,k,it

  mm1=mype+1

  do it=1,nfldsig
    do j=1,lon1*lat1
      zsm(j)=zero
    end do
 
    call strip(z(1,1,it),zsm,1)
    call mpi_gatherv(zsm,ijn(mm1),mpi_rtype,&
       work1,ijn,displs_g,mpi_rtype,&
       0,mpi_comm_world,ierror)

    if (mype==0) then
      do k=1,iglobal
        i=ltosi(k) ; j=ltosj(k)
        workh(i,j)=work1(k)
      end do
      if(regional) then
        call get_dlon_reg(workh,workd)
      else
        call compact_dlon(workh,workd,(.false.))
      end if
      do k=1,itotsub
        i=ltosi_s(k) ; j=ltosj_s(k)
        work1(k)=workd(i,j)
      end do
    end if
    call mpi_scatterv(work1,ijn_s,displs_s,mpi_rtype,&
         ztmp,ijn_s(mm1),mpi_rtype,0,mpi_comm_world,ierror)
    do j=1,lon2
      do i=1,lat2
        z_x(i,j,it)=ztmp(i,j)
      end do
    end do

    if (mype==0) then
      workd=zero
      if(regional) then
        call get_dlat_reg(workh,workd)
      else
        call compact_dlat(workh,workd,(.false.))
      end if
      do k=1,itotsub
        i=ltosi_s(k) ; j=ltosj_s(k)
        work1(k)=workd(i,j)
      end do
    end if
    call mpi_scatterv(work1,ijn_s,displs_s,mpi_rtype,&
         ztmp,ijn_s(mm1),mpi_rtype,0,mpi_comm_world,ierror)

    do j=1,lon2
      do i=1,lat2
        z_y(i,j,it)=ztmp(i,j)
      end do
    end do

  end do  ! end do loop over it

  return
end subroutine get_zderivs
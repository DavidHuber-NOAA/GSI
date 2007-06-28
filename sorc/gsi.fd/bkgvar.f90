subroutine bkgvar(t,p,q,oz,skint,cwmr,st,vp,sst,slndt,sicet,iflg)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    bkgvar      apply background error variances
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract: apply latitudinal background error variances & manipulate
!           skin temp <--> sst,sfc temp, and ice temp fields
!
! program history log:
!   1990-10-06  parrish
!   2004-08-24  kleist - hoper & htoper replaced
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-22  derber - modify for openMP
!   2005-01-22  parrish - add "use balmod"
!   2005-07-14  wu - add max bound to l2
!
!   input argument list:
!     t        - t grid values
!     p        - p surface grid values
!     q        - q grid values
!     oz       - ozone grid values
!     skint    - skin temperature grid values
!     cwmr     - cloud water mixing ratio grid values
!     st       - streamfunction grid values
!     vp       - velocity potential grid values
!     sst      - sst grid values
!     slndt    - land surface temperature grid values
!     sicet    - snow/ice covered surface temperature grid values
!     iflg     - flag for skin temperature manipulation
!                0: skint --> sst,slndt,sicet
!                1: sst,slndt,sicet --> skint
!
!   output argument list:
!     t        - t grid values
!     p        - p surface grid values
!     q        - q grid values
!     oz       - ozone grid values
!     skint    - skin temperature grid values
!     cwmr     - cloud water mixing ratio grid values
!     st       - streamfunction grid values
!     vp       - velocity potential grid values
!     sst      - sst grid values
!     slndt    - land surface temperature grid values
!     sicet    - snow/ice covered surface temperature grid values
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use kinds, only: r_kind,i_kind
  use constants, only:  one
  use balmod, only: rllat1,llmax
  use berror, only: dssv,dssv2,dssvl
  use gridmod, only: nsig,regional,lat2,lon2
  use guess_grids, only: ntguessfc,isli
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: iflg
  real(r_kind),dimension(lat2,lon2),intent(inout):: p,skint,sst,slndt,sicet
  real(r_kind),dimension(lat2,lon2,nsig),intent(inout):: t,q,cwmr,oz,st,vp

! Declare local variables
  integer(i_kind) i,j,k,l,l2
  real(r_kind) dl1,dl2

! REGIONAL BRANCH
  if (regional) then

! Apply variances
!$omp parallel do  schedule(dynamic,1) private(k,i,j,l,l2,dl2,dl1)
    do k=1,nsig
      do i=1,lon2
        do j=1,lat2
          l=int(rllat1(j,i))
          l2=min0(l+1,llmax)
          dl2=rllat1(j,i)-float(l)
          dl1=one-dl2
          st(j,i,k)  =st(j,i,k)  *(dl1*dssv(1,l,i,k)+dl2*dssv(1,l2,i,k))
          vp(j,i,k)  =vp(j,i,k)  *(dl1*dssv(2,l,i,k)+dl2*dssv(2,l2,i,k))
          t(j,i,k)   =t(j,i,k)   *(dl1*dssv(3,l,i,k)+dl2*dssv(3,l2,i,k))
          q(j,i,k)   =q(j,i,k)   *(dl1*dssv(4,l,i,k)+dl2*dssv(4,l2,i,k))
          oz(j,i,k)  =oz(j,i,k)  *(dl1*dssv(5,l,i,k)+dl2*dssv(5,l2,i,k))
          cwmr(j,i,k)=cwmr(j,i,k)*(dl1*dssv(6,l,i,k)+dl2*dssv(6,l2,i,k))
        end do
      enddo
      if(k == 1)then
! Surface fields
       do j=1,lon2
         do i=1,lat2
           l=int(rllat1(i,j))
           l2=min0(l+1,llmax)
           dl2=rllat1(i,j)-float(l)
           dl1=one-dl2
           p(i,j)=p(i,j)*(dl1*dssvl(l,1)+dl2*dssvl(l2,1))

           if(iflg == 0) then
! Break skin temperature into components
!          If land point
             if(isli(i,j,ntguessfc) == 1) then
               slndt(i,j)=skint(i,j)*(dl1*dssvl(l,2)+dl2*dssvl(l2,2))
!          If ice
             else if(isli(i,j,ntguessfc) == 2) then
               sicet(i,j)=skint(i,j)*(dl1*dssvl(l,3)+dl2*dssvl(l2,3))
!          Else treat as a water point
             else
               sst(i,j)=skint(i,j)*dssv2(i,j)
             end if

           else if (iflg.eq.1) then
! Combine sst,slndt, and sicet into skin temperature field
!          Land point, load land sfc t into skint
             if(isli(i,j,ntguessfc) == 1) then
               skint(i,j)=slndt(i,j)*(dl1*dssvl(l,2)+dl2*dssvl(l2,2))
!          Ice, load ice temp into skint
             else if(isli(i,j,ntguessfc) == 2) then
               skint(i,j)=sicet(i,j)*(dl1*dssvl(l,3)+dl2*dssvl(l2,3))
!          Treat as a water point, load sst into skint
             else
               skint(i,j)=sst(i,j)*dssv2(i,j)
             end if
           end if
         end do
       end do
      end if
    enddo

! GLOBAL BRANCH

  else
! Multipy by variances
!$omp parallel do  schedule(dynamic,1) private(k,i,j)
    do k=1,nsig
      do j=1,lon2
        do i=1,lat2
          st(i,j,k)  =st(i,j,k)  *dssv(1,i,j,k)
          vp(i,j,k)  =vp(i,j,k)  *dssv(2,i,j,k)
          t(i,j,k)   =t(i,j,k)   *dssv(3,i,j,k)
          q(i,j,k)   =q(i,j,k)   *dssv(4,i,j,k)
          oz(i,j,k)  =oz(i,j,k)  *dssv(5,i,j,k)
          cwmr(i,j,k)=cwmr(i,j,k)*dssv(6,i,j,k)
        end do
      enddo

      if(k == 1)then
! Surface fields
       do j=1,lon2
        do i=1,lat2
         p(i,j)=p(i,j)*dssvl(i,1)

         if (iflg == 0) then
! Break skin temperature into components
!        Land point
          if(isli(i,j,ntguessfc) == 1) then
            slndt(i,j)=skint(i,j)*dssvl(i,2)
!       Ice
          else if(isli(i,j,ntguessfc) == 2) then
            sicet(i,j)=skint(i,j)*dssvl(i,3)
!       Treat as a water point
          else
            sst(i,j)=skint(i,j)*dssv2(i,j)
          end if

         else if (iflg == 1) then
! Combine sst,slndt, and sicet into skin temperature field
!        Land point, load land sfc t into skint
          if(isli(i,j,ntguessfc) ==  1) then
            skint(i,j)=slndt(i,j)*dssvl(i,2)
!       Iice, load ice temp into skint
          else if(isli(i,j,ntguessfc) == 2) then
            skint(i,j)=sicet(i,j)*dssvl(i,3)
!       Else treat as a water point, load sst into skint
          else
            skint(i,j)=sst(i,j)*dssv2(i,j)
          end if
         end if
        end do
       end do
      end if
    enddo

  end if  ! end if global/regional

  return
end subroutine bkgvar
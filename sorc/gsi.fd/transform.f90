subroutine sptez_s(wave,grid,idir)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  sptez_s       perform a simple scalar spherical transform
!   prgmmr: iredell          org: np23                date: 1996-02-29
!
! absract: this subprogram performs a spherical transform
!           between spectral coefficients of a scalar quantity
!           and a field on a global cylindrical grid.
!           the wave-space can be either triangular or rhomboidal.
!           the grid-space can be either an equally-spaced grid
!           (with or without pole points) or a gaussian grid.
!           the wave field is in sequential 'ibm order'.
!           the grid field is indexed east to west, then north to south.
!           for more flexibility and efficiency, call sptran.
!           subprogram can be called from a multiprocessing environment.
!
!           This routine differs from splib routine sptez in that
!              1) the calling list only contains the in/out arrays and 
!                 flag for the direction in which to transform
!              2) it calls a version of sptranf that does not invoke 
!                 initialization routines on each entry
!              3) some generality built into the splib version is
!                 removed in the code below
!
! program history log:
!   1996-02-29  iredell
!   2004-08-23  treadon - adapt splib routine sptez for gsi use
!
!   input arguments:
!     wave     - real (2*mx) wave field if idir>0
!                where mx=(jcap+1)*((iromb+1)*jcap+2)/2
!     grid     - real (imax,jmax) grid field (e->w,n->s) if idir<0
!     idir     - integer transform flag
!                (idir>0 for wave to grid, idir<0 for grid to wave)
!
!   output arguments:
!     wave     - real (2*mx) wave field if idir<0
!                where mx=(maxwv+1)*((iromb+1)*maxwv+2)/2
!     grid     - real (imax,jmax) grid field (e->w,n->s) if idir>0
!
! subprograms called:
!   sptranf_s  -  perform a scalar spherical transform
!
! remarks: minimum grid dimensions for unaliased transforms to spectral:
!   dimension                    linear              quadratic
!   -----------------------      ---------           -------------
!   imax                         2*maxwv+2           3*maxwv/2*2+2
!   jmax (idrt=4,iromb=0)        1*maxwv+1           3*maxwv/2+1
!   jmax (idrt=4,iromb=1)        2*maxwv+1           5*maxwv/2+1
!   jmax (idrt=0,iromb=0)        2*maxwv+3           3*maxwv/2*2+3
!   jmax (idrt=0,iromb=1)        4*maxwv+3           5*maxwv/2*2+3
!   jmax (idrt=256,iromb=0)      2*maxwv+1           3*maxwv/2*2+1
!   jmax (idrt=256,iromb=1)      4*maxwv+1           5*maxwv/2*2+1
!   -----------------------      ---------           -------------
!
! attributes:
!   language: fortran 77
!
!$$$
  use kinds, only: r_kind,i_kind
  use specmod, only: nc,ijmax
  use constants, only: zero
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: idir
  real(r_kind),dimension(nc),intent(inout):: wave
  real(r_kind),dimension(ijmax),intent(inout):: grid

! Declare local variables
  integer(i_kind) i

! Zero appropriate output array based on direction of transform
  if (idir<0) then
     do i=1,nc
        wave(i)=zero
     end do
  elseif (idir>0) then
     do i=1,ijmax
        grid(i)=zero
     end do
  endif

! Call spectral <--> grid transform
  call sptranf_s(wave,grid,grid,idir)

  return
end subroutine sptez_s

subroutine sptranf_s(wave,gridn,grids,idir)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  sptranf_s     perform a scalar spherical transform
!   prgmmr: iredell          org: np23                date: 1996-02-29
!
! abstract: this subprogram performs a spherical transform
!           between spectral coefficients of scalar quantities
!           and fields on a global cylindrical grid.
!           the wave-space can be either triangular or rhomboidal.
!           the grid-space can be either an equally-spaced grid
!           (with or without pole points) or a gaussian grid.
!           the wave and grid fields may have general indexing,
!           but each wave field is in sequential 'ibm order',
!           i.e. with zonal wavenumber as the slower index.
!           transforms are done in latitude pairs for efficiency;
!           thus grid arrays for each hemisphere must be passed.
!           if so requested, just a subset of the latitude pairs
!           may be transformed in each invocation of the subprogram.
!           the transforms are all multiprocessed over latitude except
!           the transform from fourier to spectral is multiprocessed
!           over zonal wavenumber to ensure reproducibility.
!           transform several fields at a time to improve vectorization.
!           subprogram can be called from a multiprocessing environment.
!
!           This routine differs from splib routine sptranf in that
!           it does not call sptranf0 (an initialization routine).
!
! program history log:
!   1996-02-29  iredell
!   1998-12-15  iredell  generic fft used
!   2004-08-23  treadon - adapt splib routine sptranf for gsi use
!   2006-05-03  treadon - remove jc from specmod list since not used
!
!   input arguments:
!     wave     - real (*) wave fields if idir>0
!     gridn    - real (*) n.h. grid fields (starting at jb) if idir<0
!     grids    - real (*) s.h. grid fields (starting at jb) if idir<0
!     idir     - integer transform flag
!                (idir>0 for wave to grid, idir<0 for grid to wave)
!
!   output arguments:
!     wave     - real (*) wave fields if idir<0
!     gridn    - real (*) n.h. grid fields (starting at jb) if idir>0
!     grids    - real (*) s.h. grid fields (starting at jb) if idir>0
!
! subprograms called:
!   sptranf1     sptranf spectral transform
!   
! remarks: 
!   This routine assumes that splib routine sptranf0 has been 
!   previously called.  sptranf0 initializes arrays needed in
!   the transforms.
!
!   minimum grid dimensions for unaliased transforms to spectral:
!   dimension                    linear              quadratic
!   -----------------------      ---------           -------------
!   imax                         2*maxwv+2           3*maxwv/2*2+2
!   jmax (idrt=4,iromb=0)        1*maxwv+1           3*maxwv/2+1
!   jmax (idrt=4,iromb=1)        2*maxwv+1           5*maxwv/2+1
!   jmax (idrt=0,iromb=0)        2*maxwv+3           3*maxwv/2*2+3
!   jmax (idrt=0,iromb=1)        4*maxwv+3           5*maxwv/2*2+3
!   jmax (idrt=256,iromb=0)      2*maxwv+1           3*maxwv/2*2+1
!   jmax (idrt=256,iromb=1)      4*maxwv+1           5*maxwv/2*2+1
!   -----------------------      ---------           -------------
!
! attributes:
!   language: fortran 77
!
!$$$
  use kinds, only: r_kind,i_kind
  use constants, only: zero
  use specmod, only: iromb,jcap,idrt,imax,jmax,ijmax,&
       jn,js,kw,jb,je,nc,ioffset,&
       eps,epstop,enn1,elonn1,eon,eontop,&
       afft,clat,slat,wlat,pln,plntop
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: idir
  real(r_kind),dimension(nc),intent(inout):: wave
  real(r_kind),dimension(ijmax),intent(inout):: gridn
  real(r_kind),dimension(ijmax),intent(inout):: grids

! Declare local variables
  integer(i_kind) i,j,jj,ij,ijn,ijs,mp
  real(r_kind),dimension(2*(jcap+1)):: wtop
  real(r_kind),dimension(imax,2):: g

! Initialize local variables
  mp=0

  do i=1,2*(jcap+1)
     wtop(i)=zero
  end do

! Transform wave to grid
  if(idir.gt.0) then
     do j=jb,je
        call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
             eps,epstop,enn1,elonn1,eon,eontop, &
             afft,clat(j),slat(j),wlat(j), &
             pln(1,j),plntop(1,j),mp, &
             wave,wtop,g,idir)
        do i=1,imax
           jj  = j-jb
           ijn = i + jj*jn
           ijs = i + jj*js + ioffset
           gridn(ijn)=g(i,1)
           grids(ijs)=g(i,2)
        enddo
     enddo

! Transform grid to wave
  else
     do j=jb,je
        if(wlat(j).gt.0.) then
           do i=1,imax
              jj  = j-jb
              ijn = i + jj*jn
              ijs = i + jj*js + ioffset
              g(i,1)=gridn(ijn)
              g(i,2)=grids(ijs)
              
           enddo
           call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
                eps,epstop,enn1,elonn1,eon,eontop, &
                afft,clat(j),slat(j),wlat(j), &
                pln(1,j),plntop(1,j),mp, &
                wave,wtop,g,idir)
        endif
     enddo
  endif
end subroutine sptranf_s


subroutine sptez_v(waved,wavez,gridu,gridv,idir)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  sptez_v       perform a simple vector spherical transform
!   prgmmr: iredell          org: np23                date: 1996-02-29
!
! abstract: this subprogram performs a spherical transform
!           between spectral coefficients of divergence and curl
!           and a vector field on a global cylindrical grid.
!           the wave-space can be either triangular or rhomboidal.
!           the grid-space can be either an equally-spaced grid
!           (with or without pole points) or a gaussian grid.
!           the wave field is in sequential 'ibm order'.
!           the grid fiels is indexed east to west, then north to south.
!           for more flexibility and efficiency, call sptran.
!           subprogram can be called from a multiprocessing environment.
!
!           This routine differs from splib routine sptezv in that
!              1) the calling list only contains the in/out arrays and
!                 flag for the direction in which to transform
!              2) it calls a version of sptranfv that does not invoke
!                 initialization routines on each entry
!              3) some generality built into the splib version is
!                 removed in the code below
!
! program history log:
!   1996-02-29  iredell
!   2004-08-23  treadon - adapt splib routine sptezv for gsi use
!
!   input arguments:
!     waved    - real (2*mx) wave divergence field if idir>0
!                where mx=(maxwv+1)*((iromb+1)*maxwv+2)/2
!     wavez    - real (2*mx) wave vorticity field if idir>0
!                where mx=(maxwv+1)*((iromb+1)*maxwv+2)/2
!     gridu    - real (imax,jmax) grid u-wind (e->w,n->s) if idir<0
!     gridv    - real (imax,jmax) grid v-wind (e->w,n->s) if idir<0
!     idir     - integer transform flag
!                (idir>0 for wave to grid, idir<0 for grid to wave)
!
!   output arguments:
!     waved    - real (2*mx) wave divergence field if idir<0
!                where mx=(maxwv+1)*((iromb+1)*maxwv+2)/2
!     wavez    - real (2*mx) wave vorticity field if idir>0
!                where mx=(maxwv+1)*((iromb+1)*maxwv+2)/2
!     gridu    - real (imax,jmax) grid u-wind (e->w,n->s) if idir>0
!     gridv    - real (imax,jmax) grid v-wind (e->w,n->s) if idir>0
!
! subprograms called:
!   sptranf_v  - perform a vector spherical transform
!
! remarks: minimum grid dimensions for unaliased transforms to spectral:
!   dimension                    linear              quadratic
!   -----------------------      ---------           -------------
!   imax                         2*maxwv+2           3*maxwv/2*2+2
!   jmax (idrt=4,iromb=0)        1*maxwv+1           3*maxwv/2+1
!   jmax (idrt=4,iromb=1)        2*maxwv+1           5*maxwv/2+1
!   jmax (idrt=0,iromb=0)        2*maxwv+3           3*maxwv/2*2+3
!   jmax (idrt=0,iromb=1)        4*maxwv+3           5*maxwv/2*2+3
!   jmax (idrt=256,iromb=0)      2*maxwv+1           3*maxwv/2*2+1
!   jmax (idrt=256,iromb=1)      4*maxwv+1           5*maxwv/2*2+1
!   -----------------------      ---------           -------------
!
! attributes:
!   language: fortran 77
!
!$$$
  use kinds, only: r_kind,i_kind
  use specmod, only: nc,ijmax,imax,jmax
  use constants, only: zero
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: idir
  real(r_kind),dimension(nc),intent(inout):: waved,wavez
  real(r_kind),dimension(ijmax),intent(inout):: gridu,gridv

! Declare local variables
  integer(i_kind) i,j

! Zero appropriate output array based on direction of transform
  if (idir<0) then
     do i=1,nc
        waved(i)=zero
        wavez(i)=zero
     end do
  elseif (idir>0) then
     do i=1,ijmax
        gridu(i)=zero
        gridv(i)=zero
     end do
  endif

! Call spectral <--> grid transform
  call sptranf_v(waved,wavez,gridu,gridu,gridv,gridv,idir)

end subroutine sptez_v

subroutine sptranf_v(waved,wavez,gridun,gridus,gridvn,gridvs,idir)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  sptranf_v     perform a vecor spherical transform
!   prgmmr: iredell          org: np23                date: 1996-02-29
!
! abstract: this subprogram performs a spherical transform
!           between spectral coefficients of divergences and curls
!           and vector fields on a global cylindrical grid.
!           the wave-space can be either triangular or rhomboidal.
!           the grid-space can be either an equally-spaced grid
!           (with or without pole points) or a gaussian grid.
!           the wave and grid fields may have general indexing,
!           but each wave field is in sequential 'ibm order',
!           i.e. with zonal wavenumber as the slower index.
!           transforms are done in latitude pairs for efficiency;
!           thus grid arrays for each hemisphere must be passed.
!           if so requested, just a subset of the latitude pairs
!           may be transformed in each invocation of the subprogram.
!           the transforms are all multiprocessed over latitude except
!           the transform from fourier to spectral is multiprocessed
!           over zonal wavenumber to ensure reproducibility.
!           transform several fields at a time to improve vectorization.
!           subprogram can be called from a multiprocessing environment.
!
!           This routine differs from splib routine sptranfv in that
!           it does not call sptranf0 (an initialization routine).
!
! program history log:
!   1996-02-29  iredell
!   1998-12-15  iredell  generic fft used
!   2004-08-23  treadon - adapt splib routine sptranfv for gsi use
!   2006-05-03  treadon - remove jc from specmod list since not used
!   2006-07-07  kleist - correct bug in indexing of j=1,2*ncd2 loop
!
!   input arguments:
!     waved    - real (*) wave divergence fields if idir>0
!     wavez    - real (*) wave vorticity fields if idir>0
!     gridun   - real (*) n.h. grid u-winds (starting at jb) if idir<0
!     gridus   - real (*) s.h. grid u-winds (starting at jb) if idir<0
!     gridvn   - real (*) n.h. grid v-winds (starting at jb) if idir<0
!     gridvs   - real (*) s.h. grid v-winds (starting at jb) if idir<0
!     idir     - integer transform flag
!                (idir>0 for wave to grid, idir<0 for grid to wave)
!
!   output arguments:
!     waved    - real (*) wave divergence fields if idir<0
!                [waved=(d(gridu)/dlam+d(clat*gridv)/dphi)/(clat*rerth)]
!     wavez    - real (*) wave vorticity fields if idir<0
!                [wavez=(d(gridv)/dlam-d(clat*gridu)/dphi)/(clat*rerth)]
!     gridun   - real (*) n.h. grid u-winds (starting at jb) if idir>0
!     gridus   - real (*) s.h. grid u-winds (starting at jb) if idir>0
!     gridvn   - real (*) n.h. grid v-winds (starting at jb) if idir>0
!     gridvs   - real (*) s.h. grid v-winds (starting at jb) if idir>0
!
! subprograms called:
!   sptranf1     sptranf spectral transform
!   spdz2uv      compute winds from divergence and vorticity
!   spuv2dz      compute divergence and vorticity from winds
!
! remarks: 
!   This routine assumes that splib routine sptranf0 has been
!   previously called.  sptranf0 initializes arrays needed in
!   the transforms.
!
!   minimum grid dimensions for unaliased transforms to spectral:
!   dimension                    linear              quadratic
!   -----------------------      ---------           -------------
!   imax                         2*maxwv+2           3*maxwv/2*2+2
!   jmax (idrt=4,iromb=0)        1*maxwv+1           3*maxwv/2+1
!   jmax (idrt=4,iromb=1)        2*maxwv+1           5*maxwv/2+1
!   jmax (idrt=0,iromb=0)        2*maxwv+3           3*maxwv/2*2+3
!   jmax (idrt=0,iromb=1)        4*maxwv+3           5*maxwv/2*2+3
!   jmax (idrt=256,iromb=0)      2*maxwv+1           3*maxwv/2*2+1
!   jmax (idrt=256,iromb=1)      4*maxwv+1           5*maxwv/2*2+1
!   -----------------------      ---------           -------------
!
! attributes:
!   language: fortran 77
!
!$$$
  use kinds, only: r_kind,i_kind
  use specmod, only: iromb,jcap,idrt,imax,jmax,ijmax,&
       jn,js,kw,jb,je,ncd2,nc,ioffset,&
       eps,epstop,enn1,elonn1,eon,eontop,&
       afft,clat,slat,wlat,pln,plntop
  implicit none

! Declare passed variables
  integer(i_kind),intent(in):: idir
  real(r_kind),dimension(nc):: waved,wavez
  real(r_kind),dimension(ijmax):: gridun,gridus,gridvn,gridvs


! Declare local variables
  integer(i_kind) i,j,jj,ij,ijn,ijs
  integer(i_kind),dimension(2):: mp
  real(r_kind),dimension(ncd2*2,2):: w
  real(r_kind),dimension(2*(jcap+1),2):: wtop
  real(r_kind),dimension(imax,2,2):: g
  real(r_kind),dimension(ncd2*2,2):: winc

! Set parameters
  mp=1

! Transform wave to grid
  if(idir.gt.0) then
     call spdz2uv(iromb,jcap,enn1,elonn1,eon,eontop, &
          waved,wavez, &
          w(1,1),w(1,2),wtop(1,1),wtop(1,2))
     do j=jb,je
        call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
             eps,epstop,enn1,elonn1,eon,eontop, &
             afft,clat(j),slat(j),wlat(j), &
             pln(1,j),plntop(1,j),mp, &
             w(1,1),wtop(1,1),g(1,1,1),idir)
        call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
             eps,epstop,enn1,elonn1,eon,eontop, &
             afft,clat(j),slat(j),wlat(j), &
             pln(1,j),plntop(1,j),mp, &
             w(1,2),wtop(1,2),g(1,1,2),idir)
        do i=1,imax
           jj   = j-jb
           ijn = i + jj*jn
           ijs = i + jj*js + ioffset
           gridun(ijn)=g(i,1,1)
           gridus(ijs)=g(i,2,1)
           gridvn(ijn)=g(i,1,2)
           gridvs(ijs)=g(i,2,2)
           
        enddo
     enddo

!  Transform grid to wave
  else
     w=0
     wtop=0
     do j=jb,je
        if(wlat(j).gt.0.) then
           do i=1,imax
              jj   = j-jb
              ijn = i + jj*jn
              ijs = i + jj*js + ioffset

              g(i,1,1)=gridun(ijn)/clat(j)**2
              g(i,2,1)=gridus(ijs)/clat(j)**2
              g(i,1,2)=gridvn(ijn)/clat(j)**2
              g(i,2,2)=gridvs(ijs)/clat(j)**2
           enddo
           call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
                eps,epstop,enn1,elonn1,eon,eontop, &
                afft,clat(j),slat(j),wlat(j), &
                pln(1,j),plntop(1,j),mp, &
                w(1,1),wtop(1,1),g(1,1,1),idir)
           call sptranf1(iromb,jcap,idrt,imax,jmax,j,j, &
                eps,epstop,enn1,elonn1,eon,eontop, &
                afft,clat(j),slat(j),wlat(j), &
                pln(1,j),plntop(1,j),mp, &
                w(1,2),wtop(1,2),g(1,1,2),idir)
        endif
     enddo
     call spuv2dz(iromb,jcap,enn1,elonn1,eon,eontop, &
          w(1,1),w(1,2),wtop(1,1),wtop(1,2), &
          winc(1,1),winc(1,2))
     
     do j=1,2*ncd2
        waved(j)=waved(j)+winc(j,1)
        wavez(j)=wavez(j)+winc(j,2)
     end do
  endif

 end subroutine sptranf_v
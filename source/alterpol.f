c
c
c     ################################################################
c     ##  COPYRIGHT (C) 2022 by Moses Chung, Zhi Wang & Jay Ponder  ##
c     ##                    All Rights Reserved                     ##
c     ################################################################
c
c     ################################################################
c     ##                                                            ##
c     ##  subroutine alterpol  --  variable polarizability scaling  ##
c     ##                                                            ##
c     ################################################################
c
c
c     "alterpol" computes the variable polarizability scaling for
c     use with exchange polarization
c
c     literature reference:
c
c     M. K. J. Chung, Z. Wang, J. A. Rackers and J. W. Ponder,
c     "Classical Exchange Polarization: An Anisotropic Variable
c     Polarizability Model", Journal of Physical Chemistry B,
c     submitted, June 2022
c
c
      subroutine alterpol
      use limits
      use mpole
      implicit none
c
c
c     choose the method for summing over pairwise interactions
c
      if (use_mlist) then
         call altpol0b
      else
         call altpol0a
      end if
      return
      end
c
c
c     #################################################################
c     ##                                                             ##
c     ##  subroutine altpol0a  --  variable polarizability via loop  ##
c     ##                                                             ##
c     #################################################################
c
c
c     "altpol0a" computes the variable polarizability values due to
c     exchange polarization using a double loop
c
c
      subroutine altpol0a
      use atoms
      use bound
      use cell
      use couple
      use expol
      use mpole
      use polgrp
      use polpot
      use shunt
      implicit none
      integer i,j,k,m
      integer ii,kk
      integer jcell
      real*8 xi,yi,zi
      real*8 xr,yr,zr
      real*8 r,r2,r3,r4,r5
      real*8 sizi,sizk,sizik
      real*8 alphai,alphak
      real*8 springi,springk
      real*8 s2,ds2
      real*8 p33i, p33k
      real*8 ks2i(3,3)
      real*8 ks2k(3,3)
      real*8 taper
      real*8, allocatable :: pscale(:)
      logical epli,eplk
      character*6 mode
c
c
c     perform dynamic allocation of some local arrays
c
      allocate (pscale(n))
c
c     set the switching function coefficients
c
      mode = 'REPULS'
      call switch (mode)
c
c     set polarizability tensor scaling to the identity matrix
c
      do ii = 1, npole
         i = ipole(ii)
         polscale(1,1,i) = 1.0d0
         polscale(2,1,i) = 0.0d0
         polscale(3,1,i) = 0.0d0
         polscale(1,2,i) = 0.0d0
         polscale(2,2,i) = 1.0d0
         polscale(3,2,i) = 0.0d0
         polscale(1,3,i) = 0.0d0
         polscale(2,3,i) = 0.0d0
         polscale(3,3,i) = 1.0d0
      end do
c
c     set array needed to scale atom and group interactions
c
      do i = 1, n
         pscale(i) = 1.0d0
      end do
c
c     find variable polarizability scale matrix at each site
c
      do ii = 1, npole-1
         i = ipole(ii)
         xi = x(i)
         yi = y(i)
         zi = z(i)
         springi = kpep(i)
         sizi = prepep(i)
         alphai = dmppep(i)
         epli = lpep(i)
c
c     set exclusion coefficients for connected atoms
c
         do j = 1, n12(i)
            pscale(i12(j,i)) = p2scale
            do k = 1, np11(i)
               if (i12(j,i) .eq. ip11(k,i))
     &            pscale(i12(j,i)) = p2iscale
            end do
         end do
         do j = 1, n13(i)
            pscale(i13(j,i)) = p3scale
            do k = 1, np11(i)
               if (i13(j,i) .eq. ip11(k,i))
     &            pscale(i13(j,i)) = p3iscale
            end do
         end do
         do j = 1, n14(i)
            pscale(i14(j,i)) = p4scale
            do k = 1, np11(i)
               if (i14(j,i) .eq. ip11(k,i))
     &            pscale(i14(j,i)) = p4iscale
            end do
         end do
         do j = 1, n15(i)
            pscale(i15(j,i)) = p5scale
            do k = 1, np11(i)
               if (i15(j,i) .eq. ip11(k,i))
     &            pscale(i15(j,i)) = p5iscale
            end do
         end do
c
c     evaluate all sites within the cutoff distance
c
         do kk = ii+1, npole
            k = ipole(kk)
            eplk = lpep(k)
            if (epli .or. eplk) then
               xr = x(k) - xi
               yr = y(k) - yi
               zr = z(k) - zi
               if (use_bounds)  call image (xr,yr,zr)
               r2 = xr*xr + yr*yr + zr*zr
               if (r2 .le. off2) then
                  r = sqrt(r2)
                  springk = kpep(k)
                  sizk = prepep(k)
                  alphak = dmppep(k)
                  sizik = sizi * sizk
                  call dampexpl (r,sizik,alphai,alphak,s2,ds2)
c
c     use energy switching if near the cutoff distance
c
                  if (r2 .gt. cut2) then
                     r3 = r2 * r
                     r4 = r2 * r2
                     r5 = r2 * r3
                     taper = c5*r5 + c4*r4 + c3*r3
     &                          + c2*r2 + c1*r + c0
                     s2 = s2 * taper
                  end if
                  p33i = springi * s2 * pscale(k)
                  p33k = springk * s2 * pscale(k)
                  call rotexpl (r,xr,yr,zr,p33i,p33k,ks2i,ks2k)
                  do j = 1, 3
                     do m = 1, 3
                        polscale(j,m,i) = polscale(j,m,i) + ks2i(j,m)
                        polscale(j,m,k) = polscale(j,m,k) + ks2k(j,m)
                     end do
                  end do
               end if
            end if
         end do
c
c     reset exclusion coefficients for connected atoms
c
         do j = 1, n12(i)
            pscale(i12(j,i)) = 1.0d0
         end do
         do j = 1, n13(i)
            pscale(i13(j,i)) = 1.0d0
         end do
         do j = 1, n14(i)
            pscale(i14(j,i)) = 1.0d0
         end do
         do j = 1, n15(i)
            pscale(i15(j,i)) = 1.0d0
         end do
      end do
c
c     for periodic boundary conditions with large cutoffs
c     neighbors must be found by the replicates method
c
      if (use_replica) then
c
c     calculate interaction energy with other unit cells
c
         do ii = 1, npole
            i = ipole(ii)
            xi = x(i)
            yi = y(i)
            zi = z(i)
            springi = kpep(i)
            sizi = prepep(i)
            alphai = dmppep(i)
            epli = lpep(i)
c
c     set exclusion coefficients for connected atoms
c
            do j = 1, n12(i)
               pscale(i12(j,i)) = p2scale
               do k = 1, np11(i)
                  if (i12(j,i) .eq. ip11(k,i))
     &               pscale(i12(j,i)) = p2iscale
               end do
            end do
            do j = 1, n13(i)
               pscale(i13(j,i)) = p3scale
               do k = 1, np11(i)
                  if (i13(j,i) .eq. ip11(k,i))
     &               pscale(i13(j,i)) = p3iscale
               end do
            end do
            do j = 1, n14(i)
               pscale(i14(j,i)) = p4scale
               do k = 1, np11(i)
                  if (i14(j,i) .eq. ip11(k,i))
     &               pscale(i14(j,i)) = p4iscale
               end do
            end do
            do j = 1, n15(i)
               pscale(i15(j,i)) = p5scale
               do k = 1, np11(i)
                  if (i15(j,i) .eq. ip11(k,i))
     &               pscale(i15(j,i)) = p5iscale
               end do
            end do
c
c     evaluate all sites within the cutoff distance
c
            do kk = ii, npole
               k = ipole(kk)
               eplk = lpep(k)
               if (epli .or. eplk) then
                  do jcell = 2, ncell
                     xr = x(k) - xi
                     yr = y(k) - yi
                     zr = z(k) - zi
                     call imager (xr,yr,zr,jcell)
                     r2 = xr*xr + yr*yr + zr*zr
                     if (r2 .le. off2) then
                        r = sqrt(r2)
                        springk = kpep(k)
                        sizk = prepep(k)
                        alphak = dmppep(k)
                        sizik = sizi * sizk
                        call dampexpl (r,sizik,alphai,alphak,s2,ds2)
c
c     use energy switching if near the cutoff distance
c
                        if (r2 .gt. cut2) then
                           r3 = r2 * r
                           r4 = r2 * r2
                           r5 = r2 * r3
                           taper = c5*r5 + c4*r4 + c3*r3
     &                                + c2*r2 + c1*r + c0
                           s2 = s2 * taper
                        end if
c
c     interaction of an atom with its own image counts half
c
                        if (i .eq. k)  s2 = 0.5d0 * s2
                        p33i = springi * s2 * pscale(k)
                        p33k = springk * s2 * pscale(k)
                        call rotexpl (r,xr,yr,zr,p33i,p33k,ks2i,ks2k)
                        do j = 1, 3
                           do m = 1, 3
                              polscale(j,m,i) = polscale(j,m,i)
     &                                             + ks2i(j,m)
                              polscale(j,m,k) = polscale(j,m,k)
     &                                             + ks2k(j,m)
                           end do
                        end do
                     end if
                  end do
               end if
            end do
c
c     reset exclusion coefficients for connected atoms
c
            do j = 1, n12(i)
               pscale(i12(j,i)) = 1.0d0
            end do
            do j = 1, n13(i)
               pscale(i13(j,i)) = 1.0d0
            end do
            do j = 1, n14(i)
               pscale(i14(j,i)) = 1.0d0
            end do
            do j = 1, n15(i)
               pscale(i15(j,i)) = 1.0d0
            end do
         end do
      end if
c
c     find inverse of the polarizability scaling matrix
c
      do ii = 1, npole
         i = ipole(ii)
         do j = 1, 3
            do m = 1, 3
               polinv(j,m,i) = polscale(j,m,i)
            end do
         end do
         call invert (3,polinv(1,1,i))
      end do
c
c     perform deallocation of some local arrays
c
      deallocate (pscale)
      return
      end
c
c
c     #################################################################
c     ##                                                             ##
c     ##  subroutine altpol0b  --  variable polarizability via list  ##
c     ##                                                             ##
c     #################################################################
c
c
c     "altpol0b" computes variable polarizability values due to
c     exchange polarization using a neighbor list
c
c
      subroutine altpol0b
      use atoms
      use bound
      use couple
      use expol
      use mpole
      use neigh
      use polgrp
      use polpot
      use shunt
      implicit none
      integer i,j,k,m
      integer ii,kk,kkk
      real*8 xi,yi,zi
      real*8 xr,yr,zr
      real*8 r,r2,r3,r4,r5
      real*8 sizi,sizk,sizik
      real*8 alphai,alphak
      real*8 springi,springk
      real*8 s2,ds2
      real*8 p33i, p33k
      real*8 ks2i(3,3)
      real*8 ks2k(3,3)
      real*8 taper
      real*8, allocatable :: pscale(:)
      logical epli,eplk
      character*6 mode
c
c
c     perform dynamic allocation of some local arrays
c
      allocate (pscale(n))
c
c     set the switching function coefficients
c
      mode = 'REPULS'
      call switch (mode)
c
c     set polarizability tensor scaling to the identity matrix
c
      do ii = 1, npole
         i = ipole(ii)
         polscale(1,1,i) = 1.0d0
         polscale(2,1,i) = 0.0d0
         polscale(3,1,i) = 0.0d0
         polscale(1,2,i) = 0.0d0
         polscale(2,2,i) = 1.0d0
         polscale(3,2,i) = 0.0d0
         polscale(1,3,i) = 0.0d0
         polscale(2,3,i) = 0.0d0
         polscale(3,3,i) = 1.0d0
      end do
c
c     set array needed to scale atom and group interactions
c
      do i = 1, n
         pscale(i) = 1.0d0
      end do
c
c     OpenMP directives for the major loop structure
c
!$OMP PARALLEL default(private)
!$OMP& shared(npole,ipole,x,y,z,kpep,prepep,dmppep,lpep,np11,ip11,n12,
!$OMP& i12,n13,i13,n14,i14,n15,i15,p2scale,p3scale,p4scale,p5scale,
!$OMP& p2iscale,p3iscale,p4iscale,p5iscale,nelst,elst,use_bounds,
!$OMP& cut2,off2,c0,c1,c2,c3,c4,c5,polinv)
!$OMP& firstprivate(pscale)
!$OMP& shared (polscale)
!$OMP DO reduction(+:polscale) schedule(guided)
c
c     find the variable polarizability
c
      do ii = 1, npole
         i = ipole(ii)
         xi = x(i)
         yi = y(i)
         zi = z(i)
         springi = kpep(i)
         sizi = prepep(i)
         alphai = dmppep(i)
         epli = lpep(i)
c
c     set exclusion coefficients for connected atoms
c
         do j = 1, n12(i)
            pscale(i12(j,i)) = p2scale
            do k = 1, np11(i)
               if (i12(j,i) .eq. ip11(k,i))
     &            pscale(i12(j,i)) = p2iscale
            end do
         end do
         do j = 1, n13(i)
            pscale(i13(j,i)) = p3scale
            do k = 1, np11(i)
               if (i13(j,i) .eq. ip11(k,i))
     &            pscale(i13(j,i)) = p3iscale
            end do
         end do
         do j = 1, n14(i)
            pscale(i14(j,i)) = p4scale
            do k = 1, np11(i)
               if (i14(j,i) .eq. ip11(k,i))
     &            pscale(i14(j,i)) = p4iscale
            end do
         end do
         do j = 1, n15(i)
            pscale(i15(j,i)) = p5scale
            do k = 1, np11(i)
               if (i15(j,i) .eq. ip11(k,i))
     &            pscale(i15(j,i)) = p5iscale
            end do
         end do
c
c     evaluate all sites within the cutoff distance
c
         do kkk = 1, nelst(ii)
            kk = elst(kkk,ii)
            k = ipole(kk)
            eplk = lpep(k)
            if (epli .or. eplk) then
               xr = x(k) - xi
               yr = y(k) - yi
               zr = z(k) - zi
               if (use_bounds)  call image (xr,yr,zr)
               r2 = xr*xr + yr*yr + zr*zr
               if (r2 .le. off2) then
                  r = sqrt(r2)
                  springk = kpep(k)
                  sizk = prepep(k)
                  alphak = dmppep(k)
                  sizik = sizi * sizk
                  call dampexpl (r,sizik,alphai,alphak,s2,ds2)
c
c     use energy switching if near the cutoff distance
c
                  if (r2 .gt. cut2) then
                     r3 = r2 * r
                     r4 = r2 * r2
                     r5 = r2 * r3
                     taper = c5*r5 + c4*r4 + c3*r3
     &                          + c2*r2 + c1*r + c0
                     s2 = s2 * taper
                  end if
                  p33i = springi * s2 * pscale(k)
                  p33k = springk * s2 * pscale(k)
                  call rotexpl (r,xr,yr,zr,p33i,p33k,ks2i,ks2k)
                  do j = 1, 3
                     do m = 1, 3
                        polscale(j,m,i) = polscale(j,m,i) + ks2i(j,m)
                        polscale(j,m,k) = polscale(j,m,k) + ks2k(j,m)
                     end do
                  end do
               end if
            end if
         end do
c
c     reset exclusion coefficients for connected atoms
c
         do j = 1, n12(i)
            pscale(i12(j,i)) = 1.0d0
         end do
         do j = 1, n13(i)
            pscale(i13(j,i)) = 1.0d0
         end do
         do j = 1, n14(i)
            pscale(i14(j,i)) = 1.0d0
         end do
         do j = 1, n15(i)
            pscale(i15(j,i)) = 1.0d0
         end do
      end do
!$OMP END DO
c
c     find inverse of the polarizability scaling matrix
c
!$OMP DO schedule(guided)
      do ii = 1, npole
         i = ipole(ii)
         do j = 1, 3
            do m = 1, 3
               polinv(j,m,i) = polscale(j,m,i)
            end do
         end do
         call invert (3,polinv(1,1,i))
      end do
!$OMP END DO
!$OMP END PARALLEL
c
c     perform deallocation of some local arrays
c
      deallocate (pscale)
      return
      end
c
c
c     ###########################################################
c     ##                                                       ##
c     ##  subroutine rotexpl  --  rotation matrix for overlap  ##
c     ##                                                       ##
c     ###########################################################
c
c
c     "rotexpl" finds and applies rotation matrices for the
c     overlap tensor used in computing exchange polarization
c
c
      subroutine rotexpl (r,xr,yr,zr,p33i,p33k,ks2i,ks2k)
      implicit none
      integer i,j
      real*8 r,xr,yr,zr
      real*8 p33i,p33k
      real*8 a(3)
      real*8 ks2i(3,3)
      real*8 ks2k(3,3)
c
c
c     compute only needed rotation matrix elements
c
      a(1) = xr / r
      a(2) = yr / r
      a(3) = zr / r
c
c     rotate the vector from global to local frame
c
      do i = 1, 3
         do j = 1, 3
            ks2i(i,j) = p33i * a(i) * a(j)
            ks2k(i,j) = p33k * a(i) * a(j)
         end do
      end do
      return
      end

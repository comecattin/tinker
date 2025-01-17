c
c
c     ############################################################
c     ##  COPYRIGHT (C) 1996 by Yong Kong & Jay William Ponder  ##
c     ##                  All Rights Reserved                   ##
c     ############################################################
c
c     #################################################################
c     ##                                                             ##
c     ##  subroutine erxnfld3  --  reaction field energy & analysis  ##
c     ##                                                             ##
c     #################################################################
c
c
c     "erxnfld3" calculates the macroscopic reaction field energy,
c     and also partitions the energy among the atoms
c
c     literature reference:
c
c     Y. Kong and J. W. Ponder, "Reaction Field Methods for Off-Center
c     Multipoles", Journal of Chemical Physics, 107, 481-492 (1997)
c
c
      subroutine erxnfld3
      use action
      use analyz
      use atomid
      use atoms
      use chgpot
      use energi
      use inform
      use iounit
      use mpole
      use shunt
      use usage
      implicit none
      integer i,j,k
      integer ii,kk
      integer ix,iy,iz
      integer kx,ky,kz
      real*8 eik,r2
      real*8 xr,yr,zr
      real*8 r,di,dk
      real*8 rpi(13)
      real*8 rpk(13)
      logical usei,usek
      logical header,huge
      character*6 mode
c
c
c     zero out the reaction field energy and partitioning
c
      nerxf = 0
      erxf = 0.0d0
      do i = 1, n
         aerxf(i) = 0.0d0
      end do
c
c     print header information if debug output was requested
c
      header = .true.
      if (debug .and. npole.ne.0) then
         header = .false.
         write (iout,10)
   10    format (/,' Individual Reaction Field Interactions :',
     &           //,' Type',14x,'Atom Names',11x,'Dist from Origin',
     &              4x,'R(1-2)',6x,'Energy',/)
      end if
c
c     set the switching function coefficients
c
      mode = 'MPOLE'
      call switch (mode)
c
c     check the sign of multipole components at chiral sites
c
      call chkpole
c
c     rotate the multipole components into the global frame
c
      call rotpole ('MPOLE')
c
c     compute the indices used in reaction field calculations
c
      call ijkpts
c
c     calculate the reaction field interaction energy term
c
      do ii = 1, npole
         i = ipole(ii)
         iz = zaxis(i)
         ix = xaxis(i)
         iy = abs(yaxis(i))
         usei = (use(i) .or. use(iz) .or. use(ix) .or. use(iy))
         do j = 1, polsiz(i)
            rpi(j) = rpole(j,i)
         end do
         do kk = ii, npole
            k = ipole(kk)
            kz = zaxis(k)
            kx = xaxis(k)
            ky = abs(yaxis(k))
            usek = (use(k) .or. use(kz) .or. use(kx) .or. use(ky))
            if (usei .or. usek) then
               xr = x(k) - x(i)
               yr = y(k) - y(i)
               zr = z(k) - z(i)
               r2 = xr*xr + yr*yr + zr*zr
               if (r2 .le. off2) then
                  do j = 1, polsiz(k)
                     rpk(j) = rpole(j,k)
                  end do
                  call erfik (i,k,rpi,rpk,eik)
                  nerxf = nerxf + 1
                  erxf = erxf + eik
                  aerxf(i) = aerxf(i) + 0.5d0*eik
                  aerxf(k) = aerxf(k) + 0.5d0*eik
c
c     print a message if the energy of this interaction is large
c
                  huge = (eik .gt. 10.0d0)
                  if (debug .or. (verbose.and.huge)) then
                     if (header) then
                        header = .false.
                        write (iout,20)
   20                   format (/,' Individual Reaction Field',
     &                             ' Interactions :',
     &                          //,' Type',14x,'Atom Names',
     &                             11x,'Dist from Origin',4x,'R(1-2)',
     &                             6x,'Energy',/)
                     end if
                     r = sqrt(r2)
                     di = sqrt(x(i)*x(i)+y(i)*y(i)+z(i)*z(i))
                     dk = sqrt(x(k)*x(k)+y(k)*y(k)+z(k)*z(k))
                     write (iout,30)  i,name(i),k,name(k),di,dk,r,eik
   30                format (' RxnFld',4x,2(i7,'-',a3),3x,3f10.4,f12.4)
                  end if
               end if
            end if
         end do
      end do
      return
      end

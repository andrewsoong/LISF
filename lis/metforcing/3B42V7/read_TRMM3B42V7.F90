!-----------------------BEGIN NOTICE -- DO NOT EDIT-----------------------
! NASA Goddard Space Flight Center
! Land Information System Framework (LISF)
! Version 7.5
!
! Copyright (c) 2024 United States Government as represented by the
! Administrator of the National Aeronautics and Space Administration.
! All Rights Reserved.
!-------------------------END NOTICE -- DO NOT EDIT-----------------------
!BOP
!
! !ROUTINE: read_TRMM3B42V7.F90
! \label{read_TRMM3B42V7}
!
! !REVISION HISTORY: 
!  19 Apr 2013: Jonathan Case; Corrected some initializations and comparison
!               against undefined value, incorporated here by Soni Yatheendradas
!  21 Jun 2013: Soni Yatheendradas; Based on new TRMM3B42V6 code, changes from
!               earlier code to avoid (a) alternate file skip, (b) jump to
!               previous day TRMM, and (c) absence of rain rate weighting
!
! !INTERFACE:
subroutine read_TRMM3B42V7 (n, kk, fname, findex, order, ferror_TRMM3B42V7)
! !USES:
  use LIS_coreMod,           only : LIS_rc, LIS_domain
  use LIS_logMod,            only : LIS_logunit, LIS_getNextUnitNumber, &
                                    LIS_releaseUnitNumber
  use LIS_metforcingMod,     only : LIS_forc
  use TRMM3B42V7_forcingMod, only : TRMM3B42V7_struc

  implicit none
! !ARGUMENTS:
  integer, intent(in) :: n
  integer, intent(in) :: kk
  character(len=*)   :: fname
  integer, intent(in) :: findex
  integer, intent(in) :: order
  integer             :: ferror_TRMM3B42V7
!
! !DESCRIPTION:
!  For the given time, reads parameters from
!  TRMM 3B42V7 data and interpolates to the LIS domain.
!
!  The arguments are:
!  \begin{description}
!  \item[n]
!    index of the nest
!  \item[findex]
!    index of the forcing dataset
!  \item[kk]
!    index of the forecast ensemble member
!  \item[fname]
!    name of the 6 hour TRMM 3B42V7 file
!  \item[ferror\_TRMM3B42V7]
!    flag to indicate success of the call (=0 indicates success)
!  \end{description}
!
!  The routines invoked are:
!  \begin{description}
!  \item[interp\_TRMM3B42V7](\ref{interp_TRMM3B42V7}) \newline
!    spatially interpolates the TRMM 3B42V7 data
!  \end{description}
!EOP

  integer :: index1, nTRMM3B42V7

  !==== Local Variables=======================

  integer :: ios
  integer :: i,j,xd,yd
  parameter(xd=1440,yd=400)                            ! Dimension of original 3B42V7 data

  real :: precip(xd,yd)                                ! Original real precipitation array
  logical*1,allocatable  :: lb(:)
  real, allocatable :: precip_regrid(:,:)                  ! Interpolated precipitation array
  integer :: ftn

  !=== End Variable Definition =======================

  !------------------------------------------------------------------------
  ! Fill necessary arrays to assure not using old 3B42V7 data
  !------------------------------------------------------------------------
  ! J.Case (4/22/2013) -- Make consistent with Stg4/NMQ routines
  if(order.eq.1) then
     TRMM3B42V7_struc(n)%metdata1 = LIS_rc%udef ! J.Case
  elseif(order.eq.2) then 
     TRMM3B42V7_struc(n)%metdata2 = LIS_rc%udef ! J.Case
  endif
  allocate (precip_regrid(LIS_rc%lnc(n),LIS_rc%lnr(n)))
!  precip = -1.0
!  if(order.eq.1) then
!     TRMM3B42V7_struc(n)%metdata1 = -1.0
!  elseif(order.eq.2) then 
!     TRMM3B42V7_struc(n)%metdata2 = -1.0
!  endif
  precip_regrid = -1.0 ! J.Case
  !------------------------------------------------------------------------
  ! Find 3B42V7 precip data, read it in and assign to forcing precip array.
  ! Must reverse grid in latitude dimension to be consistent with LDAS grid
  !------------------------------------------------------------------------
  ftn = LIS_getNextUnitNumber()
  open(unit=ftn,file=fname, status='old', &
       &          access='direct',recl=xd*yd*4, &
       &          form='unformatted',iostat=ios)

  if (ios .eq. 0) then
     read (ftn,rec=1) precip
     Do j=1, xd
        Do i=1, yd
           if (precip(j, i) .LT. 0.0 ) precip(j, i) = 0.0    ! reset to 0 for weird values
        End Do
     End Do

! J.Case (4/19/2013) -- Test print out of raw precip array
! write (99,*) precip

     !------------------------------------------------------------------------
     ! Interpolating to desired LIS_domain and resolution
     ! Global precip datasets not used currently to force NLDAS
     !------------------------------------------------------------------------
     !print*, "Writing un-interpolated 3B42V7 precipitation out "
     !open(71, file="TRMM3B42V7-ungrid.1gd4r", access="direct", &
     !    recl=xd*yd*4, form="unformatted")
     ! write(71, rec=1) precip
     !close(71)

     nTRMM3B42V7 = TRMM3B42V7_struc(n)%ncold*TRMM3B42V7_struc(n)%nrold
     allocate(lb(nTRMM3B42V7))
     lb = .true.
     call interp_TRMM3B42V7(n, nTRMM3B42V7, precip, lb, LIS_rc%gridDesc, &
          !LIS_rc%lnc(n),LIS_rc%lnr(n),precip_regrid) ! SY
          LIS_rc%lnc(n),LIS_rc%lnr(n),precip_regrid, findex) ! SY
     deallocate (lb) 

     !print*, "Writing interpolated 3B42V7 precipitation out "
     !open(73, file="TRMM3B42V7-regrid.1gd4r", access="direct", &
     !    recl=LIS_rc%d%lnr*LIS_rc%d%lnc*4, form="unformatted")
     ! write(73, rec=1) precip_regrid
     !close(73)
     !print*, "Writing interpolated 3B42V7 precipitation out finished"

! J.Case (4/19/2013) -- Test print out of the regridded precip (on LIS grid).
! write (98,*) precip_regrid

     do j = 1,LIS_rc%lnr(n)
        do i = 1,LIS_rc%lnc(n)
           if (precip_regrid(i,j) .ne. -1.0) then
              index1 = LIS_domain(n)%gindex(i,j)
              if(index1 .ne. -1) then
                 if(order.eq.1) then 
                    TRMM3B42V7_struc(n)%metdata1(kk,1,index1) = precip_regrid(i,j)   !here is mm/h
                 elseif(order.eq.2) then 
                    TRMM3B42V7_struc(n)%metdata2(kk,1,index1) = precip_regrid(i,j)   !here is mm/h
                 endif
              endif
           endif
        enddo
     enddo

! J.Case (4/19/2013) -- Test print out of the suppdata precip (on LIS grid).
! write (97,*) TRMM3B42V7_struc(n)%metdata1(1,:)

     ferror_TRMM3B42V7 = 1
     write(LIS_logunit,*)"[INFO] Obtained 3B42 V7 precipitation data ", trim(fname)
  else
     write(LIS_logunit,*)"[WARN] Missing 3B42 V7 precipitation data ", trim(fname)
     ferror_TRMM3B42V7 = 0
  endif
  call LIS_releaseUnitNumber(ftn)

  deallocate (precip_regrid)

end subroutine read_TRMM3B42V7

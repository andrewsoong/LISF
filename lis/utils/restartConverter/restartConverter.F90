!-----------------------BEGIN NOTICE -- DO NOT EDIT-----------------------
! NASA Goddard Space Flight Center
! Land Information System Framework (LISF)
! Version 7.5
!
! Copyright (c) 2024 United States Government as represented by the
! Administrator of the National Aeronautics and Space Administration.
! All Rights Reserved.
!-------------------------END NOTICE -- DO NOT EDIT-----------------------
!
!BOP
! !ROUTINE: restartConverter
! \label{restartConverter}
! 
! !DESCRIPTION: 
!  This program converts a coarse LIS restart file to a fine resolution 
!  LIS restart file. 
!  
! !REMARKS:
! * Currently limited only to UMD landcover data 
! 
!  
! !REVISION HISTORY:
! 21 Feb 2008 : Sujay Kumar , Initial Specification
! 
! !ROUINE: 
program restartConverter

  use ESMF
  use LIS_constantsMod, only: LIS_CONST_PATH_LEN
  use map_utils

  implicit none

  type(ESMF_Config) :: rc_config
  integer           :: rc

  real              :: gridDesci(50), gridDesco(50)
  real              :: lc_gridDesci(50), lc_gridDesco(50)
  integer           :: cgnc, cgnr, fgnc, fgnr
  integer           :: nc,nr,ntiles
  type(proj_info)   :: cproj, fproj

  character(len=LIS_CONST_PATH_LEN) :: clcfile, flcfile, clmfile, flmfile
  character(len=LIS_CONST_PATH_LEN) :: input_rstfile, output_rstfile
  integer           :: nt, nfields,cnens, fnens, waterclass
  integer           :: j,c,r,t,m,ios
  integer           :: cntiles, fntiles
  integer           :: cmaxt, fmaxt
  real              :: cmina, fmina
  integer           :: clcform, flcform
  real              :: temp
  real              :: udef
  integer           :: isum 
  integer           :: ibi, ibo

  real, allocatable     :: cwts(:), fwts(:)
  integer, allocatable  :: ccol(:), crow(:)
  integer, allocatable  :: fcol(:), frow(:)
  real, allocatable     :: cmask(:,:),fmask(:,:)
  real, allocatable     :: cfgrd(:,:,:)
  real, allocatable     :: cveg(:,:,:)
  real, allocatable     :: ffgrd(:,:,:)
  real, allocatable     :: fveg(:,:,:)
  real, allocatable     :: tsum(:,:)
  real, allocatable     :: tvar(:),gvar(:),fgvar(:),ftvar(:)

  logical*1, allocatable :: li(:),lo(:)
  real, allocatable      :: rlat(:), rlon(:)
  real, allocatable      :: w11(:),w12(:),w21(:),w22(:)
  real, allocatable      :: n11(:),n12(:),n21(:),n22(:)

  udef = -9999.0

  call ESMF_Initialize()

  rc_config = ESMF_ConfigCreate(rc=rc)
  call ESMF_ConfigLoadFile(rc_config, "rc.config",rc=rc)

!--------------------------------------------------------------------------
!  Read the configuration attributes
!--------------------------------------------------------------------------
  call read_inputgrid_config(rc_config,gridDesci,lc_gridDesci, &
       cmina, cmaxt, cgnc, cgnr)

  call ESMF_ConfigGetAttribute(rc_config,cnens, &
       label="input domain number of ensembles per tile:",rc=rc)
  print*, 'input domain ens ',cnens

  call read_outputgrid_config(rc_config,gridDesco, lc_gridDesco, &
       fmina, fmaxt, fgnc, fgnr)

  call ESMF_ConfigGetAttribute(rc_config,fnens, &
       label="output domain number of ensembles per tile:",rc=rc)
  print*, 'output domain ens ',fnens

  if(gridDesci(1).eq.0) then      
     call map_set(PROJ_LATLON, gridDesci(4),gridDesci(5),&
          0.0,gridDesci(9),gridDesci(10),0.0,&
          cgnc,cgnr,cproj)     
     print*, cgnc, cgnr
  else
     Print*, 'Currently this projection (input grid) is not supported'
  endif

  if(gridDesco(1).eq.0) then      
     call map_set(PROJ_LATLON, gridDesco(4),gridDesco(5),&
          0.0,gridDesco(9),gridDesco(10),0.0,&
          fgnc,fgnr,fproj)     
     print*, fgnc, fgnr
  else
     Print*, 'Currently this projection (input grid) is not supported'
  endif

  call ESMF_ConfigGetAttribute(rc_config,clmfile, &
       label="input domain landmask file:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,clcfile, &
       label="input domain landcover file:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,clcform, &
       label="input domain landcover format:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,flmfile, &
       label="output domain landmask file:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,flcfile, &
       label="output domain landcover file:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,flcform, &
       label="output domain landcover format:",rc=rc)

  print*, 'lc1 file ',trim(clcfile)
  print*, 'lc2 file ',trim(flcfile)

  call ESMF_ConfigGetAttribute(rc_config,nt, &
       label="number of landcover types:",rc=rc)
  print*, 'nt ',nt

  call ESMF_ConfigGetAttribute(rc_config,nfields, &
       label="number of fields in the restart file:",rc=rc)
  print*, 'nfields ',nfields

  call ESMF_ConfigGetAttribute(rc_config,input_rstfile, &
       label="input LIS restart file:",rc=rc)
  print*, 'input rst file ',input_rstfile

  call ESMF_ConfigGetAttribute(rc_config,output_rstfile, &
       label="output LIS restart file:",rc=rc)
  print*, 'output rst file ',output_rstfile

#if(defined INC_WATER_PTS)
  waterclass = 14
#else
  waterclass = 16 
#endif

!--------------------------------------------------------------------------
!  Read the coarse domain land cover data
!--------------------------------------------------------------------------
  allocate(cfgrd(cgnc,cgnr,nt))
  allocate(cveg(cgnc,cgnr,nt))
  allocate(cmask(cgnc, cgnr))

  cveg = 0.0
  cfgrd = 0.0
  open(100,file=trim(clcfile),status='old',form='unformatted',&
       access='direct',recl=4,iostat=ios)
  open(101,file=trim(clmfile),status='old',form='unformatted',&
       access='direct',recl=4,iostat=ios)
  print*, 'reading ',trim(clmfile)
  print*, 'reading ',trim(clcfile)
  call read2DData(101, gridDesci, lc_gridDesci,&
       cproj, cgnc, cgnr, nt, waterclass, cmask)
  
!  if(gridDesci(9).ne.0.01) then 
  if(clcform.eq.1) then 
     call readLCData(100, gridDesci, lc_gridDesci, &
          cproj, cgnc, cgnr, nt, waterclass, cveg) 
  else
     allocate(tsum(cgnc,cgnr))
     tsum = 0.0
     call read2DData(100, gridDesci, lc_gridDesci,&
          cproj, cgnc, cgnr, nt, waterclass, tsum) 
     do r=1,cgnr
        do c=1,cgnc
#if ( defined INC_WATER_PTS )
!kludged to include water points
! The right way to do this would be read an appropriate mask and veg 
! file with water points
           if ( tsum(c,r) .le. 0 ) then 
              tsum(c,r) = waterclass
           endif
!kludge         
#endif
           if (nint(tsum(c,r)) .ne. waterclass ) then 
              print*, c,r,nint(tsum(c,r))
              cveg(c,r,NINT(tsum(c,r))) = 1.0
           endif
        enddo
     enddo
     deallocate(tsum)
  endif
  
  close(100) 
  close(101)

  do r=1,cgnr
     do c=1,cgnc
        isum=0.0
        do t=1,nt
#if ( defined INC_WATER_PTS )
           isum=isum+cveg(c,r,t)
#else
           if(t.ne.waterclass) then 
              isum=isum+cveg(c,r,t)  !recompute ISUM without water points
           endif
#endif
        enddo
        do t=1,nt 
           cfgrd(c,r,t)=0.0
#if ( defined INC_WATER_PTS )
!kluge
           if(isum.gt.0) then 
              cfgrd(c,r,t)=cveg(c,r,t)/isum
           else
              cfgrd(c,r,14) = 1.0
           endif
#else
           if(isum.gt.0) cfgrd(c,r,t)=cveg(c,r,t)/isum
#endif
        enddo
#if ( ! defined INC_WATER_PTS )
        if(waterclass.gt.0) &
             cfgrd(c,r,waterclass) = 0.0
#endif
     end do
  enddo
  deallocate(cveg)

  call calculate_domveg(cgnc,cgnr,nt,cmina, cmaxt, cfgrd)

!--------------------------------------------------------------------------
!  Create the coarse domain information
!--------------------------------------------------------------------------
  
  cntiles = 0 

  do m=1,cnens
     do r=1,cgnr
        do c=1,cgnc
           if(cmask(c,r).gt.0.99.and.&
                cmask(c,r).lt.3.01) then 
              temp = 0.0
              do t=1,nt
                 temp = temp+cfgrd(c,r,t)
                 if(cfgrd(c,r,t).gt.0.0) then
                    cntiles = cntiles+1
                 endif
              enddo
           endif
        enddo
     enddo
  enddo

  allocate(ccol(cntiles))
  allocate(crow(cntiles))
  allocate(cwts(cntiles))

  cntiles = 0 
  do m=1,cnens
     do r=1,cgnr
        do c=1,cgnc
           if(cmask(c,r).gt.0.99.and.&
                cmask(c,r).lt.3.01) then 
              
              temp = 0.0
              do t=1,nt
                 temp = temp+cfgrd(c,r,t)
                 if(cfgrd(c,r,t).gt.0.0) then
                    cntiles = cntiles+1
                    ccol(cntiles) = c
                    crow(cntiles) = r
                    cwts(cntiles) = temp
                 endif
              enddo
           endif
        enddo
     enddo
  enddo
  
  deallocate(cmask)
  deallocate(cfgrd)
  
  print*, 'input domain ntiles ',cntiles
!--------------------------------------------------------------------------
!  Read the fine domain land cover data
!--------------------------------------------------------------------------
  allocate(ffgrd(fgnc,fgnr,nt))
  allocate(fveg(fgnc,fgnr,nt))
  allocate(fmask(fgnc,fgnr))
  

  fveg = 0.0
  ffgrd = 0.0
  open(100,file=trim(flcfile),status='old',form='unformatted',&
       access='direct',recl=4,iostat=ios)
  open(101,file=trim(flmfile),status='old',form='unformatted',&
       access='direct',recl=4,iostat=ios)
  
  call read2DData(101, gridDesco, lc_gridDesco,&
       fproj, fgnc, fgnr, nt, waterclass, fmask)
 
  if(flcform.eq.1) then 
     call readLCData(100, gridDesco, lc_gridDesco, &
          fproj, fgnc, fgnr, nt, waterclass, fveg) 
  else
     allocate(tsum(fgnc,fgnr))
     tsum = 0.0
     call read2DData(100, gridDesco, lc_gridDesco,&
          fproj, fgnc, fgnr, nt, waterclass, tsum) 

     do r=1,fgnr
        do c=1,fgnc
#if ( defined INC_WATER_PTS )
!kludged to include water points
! The right way to do this would be read an appropriate mask and veg 
! file with water points
           if ( tsum(c,r) .le. 0 ) then 
              tsum(c,r) = waterclass
           endif
!kludge         
#endif
           if (nint(tsum(c,r)) .ne. waterclass ) then 
                    fveg(c,r,NINT(tsum(c,r))) = 1.0
           endif
        enddo
     enddo
     deallocate(tsum)
  endif

  close(100)
  close(101)

  do r=1,fgnr
     do c=1,fgnc
        isum=0.0
        do t=1,nt
#if ( defined INC_WATER_PTS )
           isum=isum+fveg(c,r,t)
#else
           if(t.ne.waterclass) then 
              isum=isum+fveg(c,r,t)  !recompute ISUM without water points
           endif
#endif
        enddo
        do t=1,nt 
           ffgrd(c,r,t)=0.0
#if ( defined INC_WATER_PTS )
!kluge
           if(isum.gt.0) then 
              ffgrd(c,r,t)=fveg(c,r,t)/isum
           else
              ffgrd(c,r,14) = 1.0
           endif
#else
           if(isum.gt.0) ffgrd(c,r,t)=fveg(c,r,t)/isum
#endif
        enddo
#if ( ! defined INC_WATER_PTS )
        if(waterclass.gt.0) &
             ffgrd(c,r,waterclass) = 0.0
#endif
     end do
  enddo
  deallocate(fveg)

  call calculate_domveg(fgnc,fgnr,nt,fmina, fmaxt,ffgrd)
!--------------------------------------------------------------------------
!  Create the coarse domain information
!--------------------------------------------------------------------------
  
  fntiles = 0 

  do m=1,fnens
     do r=1,fgnr
        do c=1,fgnc
           if(fmask(c,r).gt.0.99.and.&
                fmask(c,r).lt.3.01) then 
              temp = 0.0
              do t=1,nt
                 temp = temp+ffgrd(c,r,t)
                 if(ffgrd(c,r,t).gt.0.0) then 
                    fntiles = fntiles+1
                 endif
              enddo
           endif
        enddo
     enddo
  enddo

  allocate(fwts(fntiles))
  allocate(fcol(fntiles))
  allocate(frow(fntiles))

  fntiles = 0 
  do m=1,fnens
     do r=1,fgnr
        do c=1,fgnc
           if(fmask(c,r).gt.0.99.and.&
                fmask(c,r).lt.3.01) then 
              temp = 0.0
              do t=1,nt
                 temp = temp+ffgrd(c,r,t)
                 if(ffgrd(c,r,t).gt.0.0) then
                    fntiles = fntiles+1
                    fcol(fntiles) = c
                    frow(fntiles) = r
                    fwts(fntiles) = temp
                 endif
              enddo
           endif
        enddo
     enddo
  enddo
    
  deallocate(fmask)
  deallocate(ffgrd)

  print*, 'output domain ntiles ',fntiles

!--------------------------------------------------------------------------
!  Setup the interpolation weights
!--------------------------------------------------------------------------
  allocate(rlat(fgnc*fgnr))
  allocate(rlon(fgnc*fgnr))
  allocate(w11(fgnc*fgnr))
  allocate(w12(fgnc*fgnr))
  allocate(w21(fgnc*fgnr))
  allocate(w22(fgnc*fgnr))
  allocate(n11(fgnc*fgnr))
  allocate(n12(fgnc*fgnr))
  allocate(n21(fgnc*fgnr))
  allocate(n22(fgnc*fgnr))
  
  call bilinear_interp_input(gridDesci, gridDesco, fgnc*fgnr, & 
       rlat, rlon, n11, n12, n21, n22, &
       w11, w12, w21, w22)
!  call neighbor_interp_input(gridDesci, gridDesco, fgnc*fgnr, &
!       rlat, rlon, n11)

!--------------------------------------------------------------------------
!  Now read the input restar file, process each field
!--------------------------------------------------------------------------

  print*, 'Reading input restart ',trim(input_rstfile)
  open(40,file=trim(input_rstfile),form='unformatted',status='old')
  read(40) nc, nr, ntiles

  open(41,file=trim(output_rstfile),form='unformatted')
  write(41) fgnc, fgnr, fntiles*fnens

  if(nc.ne.cgnc.or.nr.ne.cgnr.or.cntiles.ne.ntiles) then 
     print*, 'The input restart file does not match the specified domain in rc.config'
     print*, 'program stopping...'
     stop
  endif
 
  allocate(tvar(cntiles))  
  allocate(gvar(cgnc*cgnr))

  allocate(li(cgnc*cgnr))
  allocate(lo(fgnc*fgnr))
  allocate(fgvar(fgnc*fgnr))
  allocate(ftvar(fntiles))

  li = .true. 
  ibi = 1

  do j=1,nfields
     print*, 'reading field ',j
     read(40) tvar

!--------------------------------------------------------------------------
!  Convert the coarse domain data to the grid space 
!--------------------------------------------------------------------------
     call tile2grid(cgnc,cgnr,cntiles, cnens, ccol, crow, cwts, tvar, gvar)
     
!     open(12,file='test1.bin',form='unformatted')
!     write(12) gvar
!     close(12) 
     
!--------------------------------------------------------------------------
!  Interpolate from coarse to fine domain
!--------------------------------------------------------------------------
     do t=1,cgnc*cgnr
        if(gvar(t).eq.udef) li(t) = .false. 
     enddo
     print*, 'interpolating field ',j
     call bilinear_interp(gridDesco,ibi,li,gvar,&
          ibo, lo, fgvar, cgnc*cgnr, fgnc*fgnr,&
          rlat, rlon, w11, w12, w21, w22, &
          n11, n12, n21, n22, udef, ios)

!     call neighbor_interp(gridDesco, ibi, li, gvar, &
!          ibo, lo, fgvar, cgnc*cgnr, fgnc*fgnr, &
!          rlat, rlon, n11, udef, ios)

!     open(12,file='test2.bin',form='unformatted')
!     write(12) fgvar
!     close(12) 
!     stop
!--------------------------------------------------------------------------
!  Convert from fine resolution grid space to tile space
!--------------------------------------------------------------------------
     print*, 'converting to tile space ',j
     call grid2tile(fgnc, fgnr, fntiles, fcol, frow, ftvar, fgvar)
     write(41) ftvar
     
  enddo
  
  close(40)
  close(41)


  print*,'program finished successfully'

end program restartConverter

subroutine read_inputgrid_config(rc_config, gridDesc, lc_gridDesc, mina, maxt, nc, nr)
  
  use ESMF

  implicit none

  type(ESMF_Config) :: rc_config
  real              :: gridDesc(50)
  real              :: lc_gridDesc(50)
  real              :: mina
  integer           :: maxt
  integer           :: grid_proj
  integer           :: nc, nr
  integer           :: rc

  gridDesc = 0 
  
  call ESMF_ConfigGetAttribute(rc_config,grid_proj,&
       label="input domain grid projection:",rc=rc)
  if(grid_proj.eq.0) then !latlon
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(4), &
          label="input domain lower left lat:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(5),&
          label="input domain lower left lon:",rc=rc)
     gridDesc(6) = 128.0
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(7),&
          label="input domain upper right lat:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(8),&
          label="input domain upper right lon:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(9),&
          label="input domain resolution dx:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(10),&
          label="input domain resolution dy:",rc=rc)
     gridDesc(11) = 64.0

     nc = nint((gridDesc(8)-gridDesc(5))/gridDesc(10))+1
     nr = nint((gridDesc(7)-gridDesc(4))/gridDesc(9))+1
     gridDesc(2) = nc
     gridDesc(3) = nr
  else
     print*, 'This projection is not supported currently. '
     stop
  endif

  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(4), &
       label="input landcover lower left lat:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(5),&
       label="input landcover lower left lon:",rc=rc)
  lc_gridDesc(6) = 128.0
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(7),&
       label="input landcover upper right lat:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(8),&
       label="input landcover upper right lon:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(9),&
       label="input landcover resolution (dx):",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(10),&
       label="input landcover resolution (dy):",rc=rc)
  lc_gridDesc(11) = 64.0
  
  lc_gridDesc(2) = nint((lc_gridDesc(8)-lc_gridDesc(5))/lc_gridDesc(10))+1
  lc_gridDesc(3) = nint((lc_gridDesc(7)-lc_gridDesc(4))/lc_gridDesc(9))+1

  call ESMF_ConfigGetAttribute(rc_config,maxt,&
       label="input maximum number of tiles per grid:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,mina,&
       label="input cutoff percentage:",rc=rc)

end subroutine read_inputgrid_config

subroutine read_outputgrid_config(rc_config, gridDesc,lc_gridDesc,mina, maxt, nc,nr)
  
  use ESMF

  implicit none

  type(ESMF_Config) :: rc_config
  real              :: gridDesc(50)
  real              :: lc_gridDesc(50)
  real              :: mina
  integer           :: maxt
  integer           :: grid_proj
  integer           :: nc,nr
  integer           :: rc

  gridDesc = 0 
  
  call ESMF_ConfigGetAttribute(rc_config,grid_proj,&
       label="output domain grid projection:",&
       rc=rc)

  if(grid_proj.eq.0) then !latlon
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(4), &
          label="output domain lower left lat:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(5),&
          label="output domain lower left lon:",rc=rc)
     gridDesc(6) = 128.0
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(7),&
          label="output domain upper right lat:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(8),&
          label="output domain upper right lon:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(9),&
          label="output domain resolution dx:",rc=rc)
     call ESMF_ConfigGetAttribute(rc_config,gridDesc(10),&
          label="output domain resolution dy:",rc=rc)
     gridDesc(11) = 64.0

     nc = nint((gridDesc(8)-gridDesc(5))/gridDesc(10))+1
     nr = nint((gridDesc(7)-gridDesc(4))/gridDesc(9))+1
     gridDesc(2) = nc
     gridDesc(3) = nr
  else
     print*, 'This projection is not supported currently. '
     stop
  endif

  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(4), &
       label="output landcover lower left lat:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(5),&
       label="output landcover lower left lon:",rc=rc)
  lc_gridDesc(6) = 128.0
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(7),&
       label="output landcover upper right lat:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(8),&
       label="output landcover upper right lon:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(9),&
       label="output landcover resolution (dx):",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,lc_gridDesc(10),&
       label="output landcover resolution (dy):",rc=rc)
  lc_gridDesc(11) = 64.0
  
  lc_gridDesc(2) = nint((lc_gridDesc(8)-lc_gridDesc(5))/lc_gridDesc(10))+1
  lc_gridDesc(3) = nint((lc_gridDesc(7)-lc_gridDesc(4))/lc_gridDesc(9))+1

  call ESMF_ConfigGetAttribute(rc_config,maxt,&
       label="output maximum number of tiles per grid:",rc=rc)
  call ESMF_ConfigGetAttribute(rc_config,mina,&
       label="output cutoff percentage:",rc=rc)
end subroutine read_outputgrid_config

subroutine readLCData(ftn, gridDesc, lc_gridDesc, proj, nc, nr, nt, waterclass, array) 

  use map_utils

  implicit none

  integer            :: ftn
  real               :: gridDesc(50)
  real               :: lc_gridDesc(50)
  type(proj_info)    :: proj
  integer            :: nc, nr, nt
  integer            :: waterclass
  real               :: array(nc,nr,nt)
  
  
  real               :: rlat(nc,nr), rlon(nc,nr)
  integer            :: c,r,t
  integer            :: nc_dom, nr_dom, line1, line2, line
  real,    allocatable   :: tsum(:,:)

  do r=1,nr
     do c=1,nc
        call ij_to_latlon(proj, float(c), float(r), rlat(c,r), rlon(c,r))
     enddo
  enddo
  
  nc_dom =  nint((lc_gridDesc(8)-lc_gridDesc(5))/(lc_gridDesc(10)))+1
  nr_dom = nint((lc_gridDesc(7)-lc_gridDesc(4))/(lc_gridDesc(9)))+1
  
   if(lc_gridDesc(9).ne.0.01) then 
#if defined ( INC_WATER_PTS )
      do t=1,nt-1
#else       
      do t=1,nt
#endif   
         do r=1,nr
            do c=1,nc
               line1 = nint((rlat(c,r)-lc_gridDesc(4))/lc_gridDesc(10))+1
               line2 = nint((rlon(c,r)-lc_gridDesc(5))/lc_gridDesc(9))+1
               line = (line1-1)*nc_dom + line2 + (t-1)*nc_dom*nr_dom
               read(ftn,rec=line) array(c,r,t)
            enddo
         enddo
      enddo
   else
      allocate(tsum(nc,nr))
      do r=1,nr
         do c=1,nc
            line1 = nint((rlat(c,r)-lc_gridDesc(4))/lc_gridDesc(10))+1
            line2 = nint((rlon(c,r)-lc_gridDesc(5))/lc_gridDesc(9))+1
            line = (line1-1)*nc_dom + line2
            read(ftn,rec=line) tsum(c,r)
#if ( defined INC_WATER_PTS )
            !kludged to include water points
               ! The right way to do this would be read an appropriate mask and veg 
               ! file with water points
            if(tsum(c,r).le.0) then 
               tsum(c,r) = waterclass
            endif
               !kludge         
#endif
            if(nint(tsum(c,r)).ne.waterclass) then 
               array(c,r,NINT(tsum(c,r))) = 1.0
            endif
         enddo
      enddo
      deallocate(tsum)
      
   endif
 end subroutine readLCData

subroutine read2DData(ftn, gridDesc, lc_gridDesc, proj, nc, nr, nt, waterclass, array) 

  use map_utils

  implicit none

  integer            :: ftn
  real               :: gridDesc(50)
  real               :: lc_gridDesc(50)
  type(proj_info)    :: proj
  integer            :: nc, nr, nt
  integer            :: waterclass
  real               :: array(nc,nr)
  
  
  real               :: rlat(nc,nr), rlon(nc,nr)
  integer            :: c,r,t
  integer            :: nc_dom, nr_dom, line1, line2, line

  do r=1,nr
     do c=1,nc
        call ij_to_latlon(proj, float(c), float(r), rlat(c,r), rlon(c,r))
     enddo
  enddo
  
  nc_dom =  nint((lc_gridDesc(8)-lc_gridDesc(5))/(lc_gridDesc(10)))+1
  do r=1,nr
     do c=1,nc
        line1 = nint((rlat(c,r)-lc_gridDesc(4))/lc_gridDesc(10))+1
        line2 = nint((rlon(c,r)-lc_gridDesc(5))/lc_gridDesc(9))+1
        line = (line1-1)*nc_dom + line2
        read(ftn,rec=line) array(c,r)
     enddo
  enddo
end subroutine read2DData

subroutine calculate_domveg(nc,nr,nt,mina,maxt,fgrd)

  implicit none

  integer        :: nc,nr,nt
  real           :: mina
  integer        :: maxt
  real           :: fgrd(nc,nr,nt)
  
  integer, allocatable :: pveg(:,:,:)
  integer          :: i,j,c,r,t
  real             :: rsum, maxv
  real             :: fvt(nt)
 
  do r=1,nr
     do c=1,nc
        rsum = 0.0
        do t=1,nt
           if(fgrd(c,r,t).lt.mina) then 
              fgrd(c,r,t) = 0.0
           endif
           rsum = rsum + fgrd(c,r,t)
        enddo
        
        if(rsum.gt.0.0) then 
           do t=1,nt
              if(rsum.gt.0.0) fgrd(c,r,t) = fgrd(c,r,t)/rsum
           enddo
           
           rsum = 0.0
           do t=1,nt
              rsum = rsum + fgrd(c,r,t)
           enddo

           if(rsum.lt.0.or.rsum.gt.1.0001) then 
              print*, 'Error in veg tiles'
              stop
           endif
        endif
     enddo
  enddo

  allocate(pveg(nc,nr,nt))
  
  do r=1,nr
     do c=1,nc
        do t=1,nt
           fvt(t) = fgrd(c,r,t)
           pveg(c,r,t) = 0
        enddo
        do i=1,nt
           maxv = 0.0
           t = 0 
           do j=1,nt
              if(fvt(j).gt.maxv) then 
                 if(fgrd(c,r,j).gt.0) then 
                    maxv = fvt(j)
                    t=j
                 endif
              endif
           enddo
           if(t.gt.0) then 
              pveg(c,r,t) = i
              fvt(t) = -999.0
           endif
        enddo
     enddo
  enddo
  
  do r=1,nr
     do c=1,nc
        rsum = 0.0
        do t=1,nt
           if(pveg(c,r,t).lt.1) then 
              fgrd(c,r,t) = 0.0
              pveg(c,r,t) = 0 
           endif
           if(pveg(c,r,t).gt.maxt) then 
              fgrd(c,r,t) = 0.0
              pveg(c,r,t) = 0 
           endif
           rsum = rsum + fgrd(c,r,t)
        enddo
        
        if(rsum.gt.0.0) then 
           do t=1,nt
              if(rsum.gt.0.0) fgrd(c,r,t) = fgrd(c,r,t)/rsum
           enddo
           rsum = 0.0
           do t=1,nt
              rsum  = rsum + fgrd(c,r,t)
           enddo
           if(rsum.lt.0.0.or.rsum.gt.1.0001) then 
              print*, 'Error in veg tiles '
              stop
           endif
        endif
     enddo
  enddo
  deallocate(pveg)
  
end subroutine calculate_domveg

subroutine tile2grid(nc,nr,ntiles, nens, col, row, fgrd, tvar, gvar)
  
  implicit none

  integer :: ntiles
  integer :: nens
  integer :: nc, nr
  integer :: col(ntiles)
  integer :: row(ntiles)
  real    :: fgrd(ntiles)
  real    :: tvar(ntiles)
  real    :: gvar(nc*nr)
  integer :: counts(nc*nr)

  integer :: i, m, t, c,r


  gvar = 0.0
  counts = 0 
  do i=1,ntiles,nens
     c = col(i)
     r = row(i)
     do m=1,nens
        t = i+m-1
        gvar(c+(r-1)*nc) = gvar(c+(r-1)*nc)+tvar(t)*fgrd(t)/nens
        counts(c+(r-1)*nc) = counts(c+(r-1)*nc) + 1
     enddo
  enddo

  do t=1,nc*nr
     if(counts(t).eq.0) gvar(t) = -9999.0
  enddo

end subroutine tile2grid

subroutine grid2tile(nc, nr, ntiles, col, row, tvar, gvar)
  
  implicit none

  integer :: nc
  integer :: nr
  integer :: ntiles
  integer :: col(ntiles)
  integer :: row(ntiles)
  real    :: tvar(ntiles)
  real    :: gvar(nc*nr)
  integer :: i, c,r
  integer :: kk, cc, rr, try
  integer :: stc, enc, str, enr
  logical :: foundPt

  do i=1,ntiles
     c = col(i)
     r = row(i)
     tvar(i) = gvar(c+(r-1)*nc)

     if(tvar(i).eq.-9999.0) then ! do a neighbor search to find a valid point
        kk = 1
        try = 1
        foundPt = .false. 
        do while (.not.foundPt) 
!           print*, 'searching ',try, c,r,kk
           stc = max(1,c-kk)
           enc = min(nc,c+kk)
           str = max(1,r-kk)
           enr = min(nr,r+kk)
          
           do cc=stc, enc
              do rr=str, enr
                 if(gvar(cc+(rr-1)*nc).ne.-9999.0) then 
!                    print*, 'found ',c,r,cc,rr,kk
                    tvar(i) = gvar(cc+(rr-1)*nc)                                       
                    foundPt = .true. 
                    exit
                 endif
              enddo
           enddo
           kk = kk+1
           try = try + 1
           if(try.ge.1000) then 
              print*, 'Not able to find a valid point through neighbor search', try, kk
              stop
           endif
        enddo
     endif

     if(tvar(i).eq.-9999.) then 
        print*, 'problem in the converted restart ',i,tvar(i)
     endif
  enddo

end subroutine grid2tile


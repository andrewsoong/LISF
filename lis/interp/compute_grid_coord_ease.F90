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
! !ROUTINE: compute_grid_coord_ease
!  \label{compute_grid_coord_ease}
!
! !REVISION HISTORY: 
!   04-10-96 Mark Iredell;  Initial Specification
!   05-27-04 Sujay Kumar; Modified verision with floating point arithmetic. 
!   06-11-07 Bailing Li; adapted from compute_grid_coord_latlon
!
! !INTERFACE:
subroutine compute_grid_coord_ease(gridDesc,npts,fill,xpts,ypts,& 
           rlon,rlat,nret)

  use map_utils
  use easeV2_utils

  implicit none
! !ARGUMENTS: 
  real            :: gridDesc(20)
  integer         :: npts
  real            :: fill
  real            :: xpts(npts),ypts(npts)
  real            :: rlat(npts)
  real            :: rlon(npts)
  integer         :: nret

! !DESCRIPTION:
!  This subroutine computes the grid coordinates of 
!  the specified domain for an cylindrical EASE projection.
!  
!  \begin{description}
!    \item[gridDesc]
!     grid description parameters 
!    \item[npts]
!     integer maximum number of coordinates
!    \item[fill]
!     fill value to set invalid output data
!    \item[xpts]
!     output grid x point coordinates
!    \item[ypts]
!     output grid y point coordinates
!    \item[rlat]    
!     input latitudes in degrees
!    \item[rlon]    
!     input longitudes in degrees
!    \end{description}
!
!EOP
  integer ezlh_convert
  real :: rlat1,rlon1,rlat2,rlon2
  real :: ul_lat,ul_lon
  real :: xstart,ystart
  real :: lat1,lon1 
  integer :: im,jm,iret,n
  integer :: nezret

  type(proj_info) :: proj
  if(gridDesc(1).eq.9) then

     if(gridDesc(9).eq.1) then !'Ml grid'
        im=gridDesc(2)
        jm=gridDesc(3)
        rlat1=gridDesc(4)
        rlon1=gridDesc(5)
        rlat2=gridDesc(7)
        rlon2=gridDesc(8)

        nret=0
        
        !find the x,y points of the upper left corner of the domain
        ul_lat=max(rlat1,rlat2)
        ul_lon=min(rlon1,rlon2)
        nezret=ezlh_convert('Ml',ul_lat,ul_lon,xstart,ystart)
        !print *,"xstart,ystart ",xstart,ystart
        
        do n=1,npts
           lat1=rlat(n)
           lon1=rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then
              nezret = ezlh_convert('Ml',lat1,lon1,xpts(n),ypts(n))
              xpts(n)=xpts(n)-xstart+1 !count starts from 1
              ypts(n)=ypts(n)-ystart+1
              nret=nret+1
           else
              xpts(n)=fill
              ypts(n)=fill
           endif
        enddo
     elseif(gridDesc(9).eq.2) then 
        do n=1,npts
           lat1 = rlat(n)
           lon1 = rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then           
              nezret = ezlh_convert('Nl',lat1,lon1,xpts(n),ypts(n))
           else
              xpts(n) = fill
              ypts(n) = fill
           endif
        enddo
     elseif(gridDesc(9).eq.3) then 
        do n=1,npts
           lat1 = rlat(n)
           lon1 = rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then           
              nezret = ezlh_convert('Sl',lat1,lon1,xpts(n),ypts(n))
           else
              xpts(n) = fill
              ypts(n) = fill
           endif
        enddo
     elseif(gridDesc(9).eq.4) then !'M36 grid'
        if(gridDesc(11).eq.1) then 
           do n=1,npts
              lat1=rlat(n)
              lon1=rlon(n)
              if (lon1>180)then
                 lon1=lon1-360
              end if
              if(abs(lon1).le.180.and.abs(lat1).le.90) then  
                 call easeV2_convert('M36',lat1,lon1,xpts(n),ypts(n))
              else
                 xpts(n) = fill
                 ypts(n) = fill
              endif
           enddo
           
        else
           call map_set(PROJ_EASEV2,gridDesc(4),gridDesc(5),&
                gridDesc(9),gridDesc(9),gridDesc(9),0.0,&
                nint(gridDesc(2)),nint(gridDesc(3)),proj)
           do n=1,npts
              call latlon_to_ij(proj,rlat(n), rlon(n), xpts(n),ypts(n))
           enddo
        endif
     elseif(gridDesc(9).eq.5) then !'M09 grid'
        if(gridDesc(11).eq.1) then 
           do n=1,npts
              lat1=rlat(n)
              lon1=rlon(n)
              if (lon1>180)then
                 lon1=lon1-360
              end if
              if(abs(lon1).le.180.and.abs(lat1).le.90) then  
                 call easeV2_convert('M09',lat1,lon1,xpts(n),ypts(n))
              else
                 xpts(n) = fill
                 ypts(n) = fill
              endif
           enddo
           
        else
           call map_set(PROJ_EASEV2,gridDesc(4),gridDesc(5),&
                gridDesc(9),gridDesc(9),gridDesc(9),0.0,&
                nint(gridDesc(2)),nint(gridDesc(3)),proj)
           do n=1,npts
              call latlon_to_ij(proj,rlat(n), rlon(n), xpts(n),ypts(n))
           enddo
        endif

     endif
  else
     iret=-1
     do n=1,npts
        xpts(n)=fill
        ypts(n)=fill
     enddo     
  endif
 
end subroutine compute_grid_coord_ease
!old version
#if 0 
subroutine compute_grid_coord_ease(gridDesc,npts,fill,xpts,ypts,& 
     rlon,rlat,nret)

  implicit none
! !ARGUMENTS: 
  real            :: gridDesc(50)
  integer         :: npts
  real            :: fill
  real            :: xpts(npts),ypts(npts)
  real            :: rlat(npts)
  real            :: rlon(npts)
  integer         :: nret

! !DESCRIPTION:
!  This subroutine computes the grid coordinates of 
!  the specified domain for an cylindrical EASE projection.
!  
!  \begin{description}
!    \item[gridDesc]
!     grid description parameters 
!    \item[npts]
!     integer maximum number of coordinates
!    \item[fill]
!     fill value to set invalid output data
!    \item[xpts]
!     output grid x point coordinates
!    \item[ypts]
!     output grid y point coordinates
!    \item[rlat]    
!     input latitudes in degrees
!    \item[rlon]    
!     input longitudes in degrees
!    \end{description}
!
!EOP
  integer ezlh_convert
  real :: rlat1,rlon1,rlat2,rlon2
  real :: ul_lat,ul_lon
  real :: xstart,ystart
  real :: lat1,lon1 
  integer :: im,jm,iret,n
  integer :: nezret
  if(gridDesc(1).eq.9) then

     if(gridDesc(9).eq.1) then !'Ml grid'
        im=gridDesc(2)
        jm=gridDesc(3)
        rlat1=gridDesc(4)
        rlon1=gridDesc(5)
        rlat2=gridDesc(7)
        rlon2=gridDesc(8)

        nret=0
        
        !find the x,y points of the upper left corner of the domain
        ul_lat=max(rlat1,rlat2)
        ul_lon=min(rlon1,rlon2)
        nezret=ezlh_convert('Ml',ul_lat,ul_lon,xstart,ystart)
        !print *,"xstart,ystart ",xstart,ystart
        
        do n=1,npts
           lat1=rlat(n)
           lon1=rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then
              nezret = ezlh_convert('Ml',lat1,lon1,xpts(n),ypts(n))
              xpts(n)=xpts(n)-xstart+1 !count starts from 1
              ypts(n)=ypts(n)-ystart+1
              nret=nret+1
           else
              xpts(n)=fill
              ypts(n)=fill
           endif
        enddo
     elseif(gridDesc(9).eq.2) then 
        do n=1,npts
           lat1 = rlat(n)
           lon1 = rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then           
              nezret = ezlh_convert('Nl',lat1,lon1,xpts(n),ypts(n))
           else
              xpts(n) = fill
              ypts(n) = fill
           endif
        enddo
     elseif(gridDesc(9).eq.3) then 
        do n=1,npts
           lat1 = rlat(n)
           lon1 = rlon(n)
           if (lon1>180)then
              lon1=lon1-360
           end if
           if(abs(lon1).le.180.and.abs(lat1).le.90) then           
              nezret = ezlh_convert('Sl',lat1,lon1,xpts(n),ypts(n))
           else
              xpts(n) = fill
              ypts(n) = fill
           endif
        enddo
     endif
  else
     iret=-1
     do n=1,npts
        xpts(n)=fill
        ypts(n)=fill
     enddo     
  endif
 
end subroutine compute_grid_coord_ease
#endif

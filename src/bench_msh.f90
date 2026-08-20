module bench_msh
    !! The FreeFem++ .msh dialect MEPHIT writes and reads for the outer mesh.
    !!
    !!   npoints ntriangles nsegments
    !!   R Z 0                          x npoints
    !!   n1 n2 n3 1                     x ntriangles
    !!   n1 n2 2                        x nsegments
    !!
    !! Vertex indices are one-based. The trailing integers are the FreeFem
    !! labels: 0 for interior vertices, region 1 for the annulus, boundary
    !! label 2 for the constrained segments.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: msh_t, read_msh, write_msh

    type :: msh_t
        integer :: npoint = 0
        integer :: ntri = 0
        integer :: nseg = 0
        real(dp), allocatable :: R(:)
        real(dp), allocatable :: Z(:)
        integer, allocatable :: tri(:, :)
        integer, allocatable :: seg(:, :)
    end type msh_t

contains

    subroutine read_msh(filename, m, stat, msg)
        character(len=*), intent(in) :: filename
        type(msh_t), intent(out) :: m
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        integer :: fid, k, ios, label

        msg = ''
        open (newunit=fid, file=trim(filename), status='old', action='read', &
              form='formatted', iostat=ios)
        if (ios /= 0) then
            stat = 1
            msg = 'cannot open '//trim(filename)
            return
        end if
        read (fid, *, iostat=ios) m%npoint, m%ntri, m%nseg
        if (ios /= 0 .or. m%npoint < 3 .or. m%ntri < 1 .or. m%nseg < 3) then
            stat = 2
            msg = 'bad header in '//trim(filename)
            close (fid)
            return
        end if
        allocate (m%R(m%npoint), m%Z(m%npoint))
        allocate (m%tri(3, m%ntri), m%seg(2, m%nseg))
        do k = 1, m%npoint
            read (fid, *, iostat=ios) m%R(k), m%Z(k), label
            if (ios /= 0) exit
        end do
        if (ios == 0) then
            do k = 1, m%ntri
                read (fid, *, iostat=ios) m%tri(:, k), label
                if (ios /= 0) exit
            end do
        end if
        if (ios == 0) then
            do k = 1, m%nseg
                read (fid, *, iostat=ios) m%seg(:, k), label
                if (ios /= 0) exit
            end do
        end if
        close (fid)
        if (ios /= 0) then
            stat = 3
            msg = 'truncated mesh in '//trim(filename)
            return
        end if
        if (minval(m%tri) < 1 .or. maxval(m%tri) > m%npoint .or. &
            minval(m%seg) < 1 .or. maxval(m%seg) > m%npoint) then
            stat = 4
            msg = 'vertex index out of range in '//trim(filename)
            return
        end if
        stat = 0
    end subroutine read_msh

    subroutine write_msh(filename, m, stat, msg)
        character(len=*), intent(in) :: filename
        type(msh_t), intent(in) :: m
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        integer :: fid, k, ios

        msg = ''
        open (newunit=fid, file=trim(filename), status='replace', &
              action='write', form='formatted', iostat=ios)
        if (ios /= 0) then
            stat = 1
            msg = 'cannot write '//trim(filename)
            return
        end if
        write (fid, '(i0, 2(1x, i0))') m%npoint, m%ntri, m%nseg
        do k = 1, m%npoint
            write (fid, '(es24.16e3, 1x, es24.16e3, " 0")') m%R(k), m%Z(k)
        end do
        do k = 1, m%ntri
            write (fid, '(i0, 2(1x, i0), " 1")') m%tri(:, k)
        end do
        do k = 1, m%nseg
            write (fid, '(i0, 1x, i0, " 2")') m%seg(:, k)
        end do
        close (fid)
        stat = 0
    end subroutine write_msh

end module bench_msh

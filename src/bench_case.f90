module bench_case
    !! Annulus meshing problem as MEPHIT poses it: an inner boundary loop
    !! taken from the outermost meshed flux surface, an outer loop on the
    !! doubled bounding ellipse, and one hole marker inside the inner loop.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: case_t, read_case, case_npoint, case_segments

    type :: case_t
        character(len=:), allocatable :: name
        integer :: npt_inner = 0
        integer :: npt_outer = 0
        real(dp) :: R_hole = 0.0_dp
        real(dp) :: Z_hole = 0.0_dp
        real(dp), allocatable :: bdry_R(:)
        real(dp), allocatable :: bdry_Z(:)
    end type case_t

contains

    subroutine read_case(dirname, c, stat, msg)
        !! Read <dirname>/boundary.dat as written by MEPHIT's write_FreeFem_mesh.
        character(len=*), intent(in) :: dirname
        type(case_t), intent(out) :: c
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        integer :: fid, k, ios, npoint

        msg = ''
        open (newunit=fid, file=trim(dirname)//'/boundary.dat', status='old', &
              action='read', form='formatted', iostat=ios)
        if (ios /= 0) then
            stat = 1
            msg = 'cannot open '//trim(dirname)//'/boundary.dat'
            return
        end if
        read (fid, *, iostat=ios) c%npt_inner, c%npt_outer
        if (ios /= 0 .or. c%npt_inner < 3 .or. c%npt_outer < 3) then
            stat = 2
            msg = 'bad point counts in boundary.dat'
            close (fid)
            return
        end if
        read (fid, *, iostat=ios) c%R_hole, c%Z_hole
        if (ios /= 0) then
            stat = 3
            msg = 'bad hole marker in boundary.dat'
            close (fid)
            return
        end if
        npoint = c%npt_inner + c%npt_outer
        allocate (c%bdry_R(npoint), c%bdry_Z(npoint))
        do k = 1, npoint
            read (fid, *, iostat=ios) c%bdry_R(k), c%bdry_Z(k)
            if (ios /= 0) then
                stat = 4
                msg = 'truncated point list in boundary.dat'
                close (fid)
                return
            end if
        end do
        close (fid)
        c%name = basename(dirname)
        stat = 0
    end subroutine read_case

    pure function case_npoint(c) result(n)
        type(case_t), intent(in) :: c
        integer :: n

        n = c%npt_inner + c%npt_outer
    end function case_npoint

    subroutine case_segments(c, seg)
        !! Input segments in MEPHIT's order: the inner loop closed on itself,
        !! then the outer loop closed on itself. One-based vertex indices.
        type(case_t), intent(in) :: c
        integer, allocatable, intent(out) :: seg(:, :)
        integer :: k

        allocate (seg(2, case_npoint(c)))
        do k = 1, c%npt_inner
            seg(1, k) = k
            seg(2, k) = modulo(k, c%npt_inner) + 1
        end do
        do k = 1, c%npt_outer
            seg(1, c%npt_inner + k) = c%npt_inner + k
            seg(2, c%npt_inner + k) = c%npt_inner + modulo(k, c%npt_outer) + 1
        end do
    end subroutine case_segments

    function basename(path) result(name)
        character(len=*), intent(in) :: path
        character(len=:), allocatable :: name
        integer :: last, cut

        last = len_trim(path)
        do while (last > 1 .and. path(last:last) == '/')
            last = last - 1
        end do
        cut = index(path(:last), '/', back=.true.)
        name = path(cut + 1:last)
    end function basename

end module bench_case

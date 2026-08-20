module bench_backend
    !! Backend dispatch. Every backend writes the same FreeFem .msh file, so
    !! comparing meshers is comparing files, not APIs.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use iso_c_binding, only: c_int, c_double, c_char, c_null_char
    use bench_case, only: case_t, case_npoint, case_segments
    use bench_msh, only: msh_t, read_msh, write_msh
    use backend_fortfem, only: fortfem_mesh_annulus
    implicit none
    private

    public :: available_backends, backend_available, mesh_annulus

#ifdef BENCH_WITH_TRIANGLE
    interface
        function bench_triangle_mesh(npt_inner, npt_outer, bdry_R, bdry_Z, &
                                     R_hole, Z_hole, fname) bind(C)
            import :: c_int, c_double, c_char
            integer(c_int), value :: npt_inner, npt_outer
            real(c_double), intent(in) :: bdry_R(*), bdry_Z(*)
            real(c_double), value :: R_hole, Z_hole
            character(kind=c_char), intent(in) :: fname(*)
            integer(c_int) :: bench_triangle_mesh
        end function bench_triangle_mesh
    end interface
#endif

#ifdef BENCH_WITH_DELAUNAY32
    interface
        function bench_delaunay32_mesh(npt_inner, npt_outer, bdry_R, bdry_Z, &
                                       R_hole, Z_hole, fname) bind(C)
            import :: c_int, c_double, c_char
            integer(c_int), value :: npt_inner, npt_outer
            real(c_double), intent(in) :: bdry_R(*), bdry_Z(*)
            real(c_double), value :: R_hole, Z_hole
            character(kind=c_char), intent(in) :: fname(*)
            integer(c_int) :: bench_delaunay32_mesh
        end function bench_delaunay32_mesh
    end interface
#endif

contains

    function available_backends() result(list)
        character(len=:), allocatable :: list

        list = 'fortfem'
#ifdef BENCH_WITH_DELAUNAY32
        list = list//' delaunay32'
#endif
#ifdef BENCH_WITH_TRIANGLE
        list = list//' triangle'
#endif
    end function available_backends

    function backend_available(name) result(ok)
        character(len=*), intent(in) :: name
        logical :: ok

        ok = index(' '//available_backends()//' ', ' '//trim(name)//' ') > 0
    end function backend_available

    subroutine mesh_annulus(backend, c, outfile, min_angle, translate, stat, msg)
        !! Mesh one case with one backend and write the result as a .msh file.
        !!
        !! translate shifts the problem to the hole marker before meshing and
        !! shifts the result back. MEPHIT itself does not do this; the option
        !! exists to separate a mesher's robustness from the 1.7e5 cm
        !! coordinate offset the KiLCA cases carry.
        character(len=*), intent(in) :: backend
        type(case_t), intent(in) :: c
        character(len=*), intent(in) :: outfile
        real(dp), intent(in) :: min_angle
        logical, intent(in) :: translate
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        type(msh_t) :: m
        integer, allocatable :: seg(:, :)
        real(dp), allocatable :: R(:), Z(:)
        real(dp) :: R0, Z0
        integer :: rc

        msg = ''
        if (translate) then
            R0 = c%R_hole
            Z0 = c%Z_hole
        else
            R0 = 0.0_dp
            Z0 = 0.0_dp
        end if
        R = c%bdry_R - R0
        Z = c%bdry_Z - Z0

        select case (trim(backend))
        case ('fortfem')
            call case_segments(c, seg)
            call fortfem_mesh_annulus(R, Z, seg, c%R_hole - R0, c%Z_hole - Z0, &
                                      min_angle, m, stat, msg)
            if (stat /= 0) return
            m%R = m%R + R0
            m%Z = m%Z + Z0
            call write_msh(outfile, m, stat, msg)
#ifdef BENCH_WITH_DELAUNAY32
        case ('delaunay32')
            rc = bench_delaunay32_mesh(int(c%npt_inner, c_int), &
                                       int(c%npt_outer, c_int), R, Z, &
                                       c%R_hole - R0, c%Z_hole - Z0, &
                                       trim(outfile)//c_null_char)
            call finish_c_backend(rc, outfile, R0, Z0, stat, msg)
#endif
#ifdef BENCH_WITH_TRIANGLE
        case ('triangle')
            rc = bench_triangle_mesh(int(c%npt_inner, c_int), &
                                     int(c%npt_outer, c_int), R, Z, &
                                     c%R_hole - R0, c%Z_hole - Z0, &
                                     trim(outfile)//c_null_char)
            call finish_c_backend(rc, outfile, R0, Z0, stat, msg)
#endif
        case default
            stat = 90
            msg = 'unknown backend "'//trim(backend)//'"; available: '// &
                  available_backends()
        end select
    end subroutine mesh_annulus

    subroutine finish_c_backend(rc, outfile, R0, Z0, stat, msg)
        !! C and C++ backends write the mesh themselves; shift it back into
        !! machine coordinates if the problem was translated.
        integer, intent(in) :: rc
        character(len=*), intent(in) :: outfile
        real(dp), intent(in) :: R0, Z0
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        type(msh_t) :: m

        msg = ''
        if (rc /= 0) then
            stat = 80 + rc
            msg = 'backend returned nonzero status'
            return
        end if
        if (R0 == 0.0_dp .and. Z0 == 0.0_dp) then
            stat = 0
            return
        end if
        call read_msh(outfile, m, stat, msg)
        if (stat /= 0) return
        m%R = m%R + R0
        m%Z = m%Z + Z0
        call write_msh(outfile, m, stat, msg)
    end subroutine finish_c_backend

end module bench_backend

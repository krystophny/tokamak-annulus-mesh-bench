module backend_fortfem
    !! fortfem's triangle_compat: a Fortran reimplementation of Triangle's
    !! "pqY" pipeline (constrained Delaunay, hole carving, quality refinement).
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use triangle_compat, only: tc_result_t, triangulate_compat
    use bench_msh, only: msh_t
    implicit none
    private

    public :: fortfem_mesh_annulus

contains

    subroutine fortfem_mesh_annulus(bdry_R, bdry_Z, seg, R_hole, Z_hole, &
                                    min_angle, m, stat, msg)
        real(dp), intent(in) :: bdry_R(:), bdry_Z(:)
        integer, intent(in) :: seg(:, :)
        real(dp), intent(in) :: R_hole, Z_hole, min_angle
        type(msh_t), intent(out) :: m
        integer, intent(out) :: stat
        character(len=:), allocatable, intent(out) :: msg
        type(tc_result_t) :: res
        real(dp), allocatable :: points(:, :), holes(:, :)
        integer :: n

        msg = ''
        n = size(bdry_R)
        allocate (points(2, n))
        points(1, :) = bdry_R(:)
        points(2, :) = bdry_Z(:)
        allocate (holes(2, 1))
        holes(1, 1) = R_hole
        holes(2, 1) = Z_hole

        call triangulate_compat(points, seg, holes, res, stat, &
                                min_angle=min_angle, quality=.true., nobisect=1)
        if (stat /= 0) then
            msg = 'triangulate_compat failed'
            return
        end if

        m%npoint = res%npoints
        m%ntri = res%ntriangles
        m%nseg = res%nsegments
        allocate (m%R(m%npoint), m%Z(m%npoint))
        m%R(:) = res%points(1, :)
        m%Z(:) = res%points(2, :)
        allocate (m%tri(3, m%ntri))
        m%tri(:, :) = res%triangles(:, :)
        allocate (m%seg(2, m%nseg))
        m%seg(:, :) = res%segments(:, :)
    end subroutine fortfem_mesh_annulus

end module backend_fortfem

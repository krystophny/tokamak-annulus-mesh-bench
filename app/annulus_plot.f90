program annulus_plot
    !! Two plots per mesh, via fortplot: the wireframe and the angle
    !! distribution against the 20 degree target.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use fortplot, only: figure, plot, hist, title, xlabel, ylabel, axvline, &
        savefig, legend
    use bench_case, only: case_t, read_case
    use bench_msh, only: msh_t, read_msh
    use bench_quality, only: report_t, evaluate
    implicit none

    integer, parameter :: MAX_WIREFRAME_TRIANGLES = 40000
    real(dp), parameter :: MESH_COLOR(3) = [0.25_dp, 0.45_dp, 0.75_dp]
    real(dp), parameter :: BOUNDARY_COLOR(3) = [0.80_dp, 0.15_dp, 0.15_dp]

    character(len=4096) :: buffer
    character(len=:), allocatable :: case_dir, meshfile, prefix, msg
    type(case_t) :: c
    type(msh_t) :: m
    type(report_t) :: rep
    real(dp) :: tx(4), ty(4)
    real(dp) :: R0, Z0
    integer :: stat, k

    if (command_argument_count() < 3) then
        write (*, '(a)') 'usage: annulus_plot <case-dir> <mesh.msh> <out-prefix>'
        stop 2
    end if
    call get_command_argument(1, buffer); case_dir = trim(buffer)
    call get_command_argument(2, buffer); meshfile = trim(buffer)
    call get_command_argument(3, buffer); prefix = trim(buffer)

    call read_case(case_dir, c, stat, msg)
    if (stat /= 0) then
        write (*, '(a)') 'error: '//msg
        stop 3
    end if
    call read_msh(meshfile, m, stat, msg)
    if (stat /= 0) then
        write (*, '(a)') 'error: '//msg
        stop 3
    end if
    call evaluate(c, m, rep)

    ! Plot relative to the hole marker: the KiLCA cases sit at R ~ 1.7e5 cm
    ! with a 270 cm wide annulus, which no axis formatting survives.
    R0 = c%R_hole
    Z0 = c%Z_hole

    call figure()
    if (m%ntri <= MAX_WIREFRAME_TRIANGLES) then
        do k = 1, m%ntri
            tx = [m%R(m%tri(1, k)), m%R(m%tri(2, k)), m%R(m%tri(3, k)), &
                  m%R(m%tri(1, k))] - R0
            ty = [m%Z(m%tri(1, k)), m%Z(m%tri(2, k)), m%Z(m%tri(3, k)), &
                  m%Z(m%tri(1, k))] - Z0
            call plot(tx, ty, linestyle='-', color=MESH_COLOR, &
                      linewidth=0.4_dp)
        end do
    else
        write (*, '(a, i0, a)') 'note: ', m%ntri, &
            ' triangles exceed the wireframe limit; plotting boundary only'
    end if
    call plot([c%bdry_R(1:c%npt_inner), c%bdry_R(1)] - R0, &
              [c%bdry_Z(1:c%npt_inner), c%bdry_Z(1)] - Z0, &
              linestyle='-', color=BOUNDARY_COLOR, linewidth=1.5_dp)
    call plot([c%bdry_R(c%npt_inner + 1:), c%bdry_R(c%npt_inner + 1)] - R0, &
              [c%bdry_Z(c%npt_inner + 1:), c%bdry_Z(c%npt_inner + 1)] - Z0, &
              linestyle='-', color=BOUNDARY_COLOR, linewidth=1.5_dp)
    call title(c%name//' mesh: '//trim(itoa(m%ntri))//' triangles')
    call xlabel('R - R_hole / cm')
    call ylabel('Z - Z_hole / cm')
    call savefig(prefix//'_mesh.png')

    call figure()
    call hist(rep%angles, bins=90, color=MESH_COLOR)
    call axvline(20.0_dp, linestyle='--', color='r')
    call title(c%name//': minimum angle '//trim(ftoa(rep%min_angle))//' deg')
    call xlabel('triangle angle / deg')
    call ylabel('count')
    call savefig(prefix//'_angles.png')

    write (*, '(a)') 'wrote '//prefix//'_mesh.png and '//prefix//'_angles.png'

contains

    function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=16) :: s

        write (s, '(i0)') i
    end function itoa

    function ftoa(x) result(s)
        real(dp), intent(in) :: x
        character(len=16) :: s

        write (s, '(f0.2)') x
    end function ftoa

end program annulus_plot

program annulus_check
    !! Check an existing .msh against a case -- for the shipped Triangle
    !! reference meshes, or for a mesh produced by a mesher outside this repo.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use bench_case, only: case_t, read_case
    use bench_msh, only: msh_t, read_msh
    use bench_quality, only: report_t, evaluate, report_ok, print_report
    implicit none

    character(len=4096) :: buffer
    character(len=:), allocatable :: case_dir, meshfile, msg
    type(case_t) :: c
    type(msh_t) :: m
    type(report_t) :: rep
    real(dp) :: min_angle, area_tol
    integer :: stat, k, npos

    min_angle = 20.0_dp
    area_tol = 1.0e-8_dp
    case_dir = ''
    meshfile = ''
    npos = 0
    k = 1
    do while (k <= command_argument_count())
        call get_command_argument(k, buffer)
        select case (trim(buffer))
        case ('--min-angle')
            k = k + 1
            call get_command_argument(k, buffer)
            read (buffer, *) min_angle
        case ('--area-tol')
            k = k + 1
            call get_command_argument(k, buffer)
            read (buffer, *) area_tol
        case default
            npos = npos + 1
            if (npos == 1) then
                case_dir = trim(buffer)
            else if (npos == 2) then
                meshfile = trim(buffer)
            end if
        end select
        k = k + 1
    end do
    if (case_dir == '' .or. meshfile == '') then
        write (*, '(a)') 'usage: annulus_check <case-dir> <mesh.msh> '// &
            '[--min-angle DEG] [--area-tol X]'
        stop 2
    end if

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
    call print_report(rep, c%name//' / '//trim(meshfile), min_angle, area_tol)
    if (.not. report_ok(rep, min_angle, area_tol)) then
        write (*, '(a)') 'RESULT  FAIL'
        stop 1
    end if
    write (*, '(a)') 'RESULT  PASS'

end program annulus_check

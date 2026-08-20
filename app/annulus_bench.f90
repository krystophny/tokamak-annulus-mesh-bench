program annulus_bench
    !! Mesh one case with one backend, write the .msh, and check it against
    !! the contract MEPHIT imposes on the vacuum annulus mesh.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use bench_case, only: case_t, read_case, case_npoint
    use bench_msh, only: msh_t, read_msh
    use bench_backend, only: mesh_annulus, available_backends, backend_available
    use bench_quality, only: report_t, evaluate, report_ok, print_report
    implicit none

    character(len=:), allocatable :: case_dir, backend, outfile, msg
    type(case_t) :: c
    type(msh_t) :: m
    type(report_t) :: rep
    real(dp) :: min_angle, area_tol, t0, t1
    logical :: translate
    integer :: stat

    call parse_arguments(case_dir, backend, outfile, min_angle, area_tol, translate)

    call read_case(case_dir, c, stat, msg)
    if (stat /= 0) call die(msg)
    if (.not. backend_available(backend)) then
        call die('backend "'//backend//'" not built; available: '// &
                 available_backends())
    end if

    write (*, '(a)') 'case    '//c%name//'  ('//trim(itoa(c%npt_inner))// &
        ' inner + '//trim(itoa(c%npt_outer))//' outer boundary points)'
    write (*, '(a)') 'backend '//backend

    call cpu_time(t0)
    call mesh_annulus(backend, c, outfile, min_angle, translate, stat, msg)
    call cpu_time(t1)
    if (stat /= 0) call die(msg)
    write (*, '(a, f8.3, a)') 'time    ', t1 - t0, ' s'
    write (*, '(a)') 'mesh    '//outfile

    call read_msh(outfile, m, stat, msg)
    if (stat /= 0) call die(msg)
    call evaluate(c, m, rep)
    call print_report(rep, c%name//' / '//backend, min_angle, area_tol)

    if (.not. report_ok(rep, min_angle, area_tol)) then
        write (*, '(a)') 'RESULT  FAIL'
        stop 1
    end if
    write (*, '(a)') 'RESULT  PASS'

contains

    subroutine parse_arguments(case_dir, backend, outfile, min_angle, area_tol, &
                               translate)
        character(len=:), allocatable, intent(out) :: case_dir, backend, outfile
        real(dp), intent(out) :: min_angle, area_tol
        logical, intent(out) :: translate
        character(len=4096) :: buffer
        integer :: k, npos

        min_angle = 20.0_dp
        area_tol = 1.0e-8_dp
        translate = .false.
        outfile = ''
        case_dir = ''
        backend = ''
        npos = 0
        k = 1
        do while (k <= command_argument_count())
            call get_command_argument(k, buffer)
            select case (trim(buffer))
            case ('--translate')
                translate = .true.
            case ('--min-angle')
                k = k + 1
                call get_command_argument(k, buffer)
                read (buffer, *) min_angle
            case ('--area-tol')
                k = k + 1
                call get_command_argument(k, buffer)
                read (buffer, *) area_tol
            case ('--out')
                k = k + 1
                call get_command_argument(k, buffer)
                outfile = trim(buffer)
            case ('-h', '--help')
                call usage()
                stop 0
            case default
                npos = npos + 1
                if (npos == 1) then
                    case_dir = trim(buffer)
                else if (npos == 2) then
                    backend = trim(buffer)
                end if
            end select
            k = k + 1
        end do
        if (case_dir == '' .or. backend == '') then
            call usage()
            stop 2
        end if
        if (outfile == '') outfile = 'outer.msh'
    end subroutine parse_arguments

    subroutine usage()
        write (*, '(a)') 'usage: annulus_bench <case-dir> <backend> [options]'
        write (*, '(a)') '  --out FILE        output mesh (default outer.msh)'
        write (*, '(a)') '  --min-angle DEG   quality target (default 20)'
        write (*, '(a)') '  --area-tol X      area tolerance (default 1e-8)'
        write (*, '(a)') '  --translate       shift to the hole marker before meshing'
        write (*, '(a)') 'backends: '//available_backends()
    end subroutine usage

    subroutine die(text)
        character(len=*), intent(in) :: text

        write (*, '(a)') 'error: '//trim(text)
        stop 3
    end subroutine die

    function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=16) :: s

        write (s, '(i0)') i
    end function itoa

end program annulus_bench

module bench_quality
    !! Contract checks for an annulus mesh, phrased exactly as MEPHIT needs
    !! them: Triangle is called with "BejnpqYz", so the boundary must survive
    !! unsplit, the hole must be respected, and no triangle may fall below
    !! 20 degrees.
    !!
    !! All geometry is evaluated relative to the hole marker. The production
    !! cases sit at R ~ 1.7e5 cm with 0.5 cm edges, so evaluating areas in
    !! absolute coordinates loses roughly ten digits to cancellation.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use bench_case, only: case_t, case_npoint, case_segments
    use bench_msh, only: msh_t
    implicit none
    private

    public :: report_t, evaluate, report_ok, print_report

    real(dp), parameter :: PI = 3.141592653589793_dp

    type :: report_t
        integer :: npoint = 0
        integer :: ntri = 0
        integer :: nseg = 0
        integer :: nseg_expected = 0
        integer :: n_input_moved = 0
        integer :: n_segment_lost = 0
        integer :: n_inverted = 0
        integer :: n_outside = 0
        real(dp) :: min_angle = 0.0_dp
        real(dp) :: area = 0.0_dp
        real(dp) :: area_expected = 0.0_dp
        real(dp) :: area_rel_err = 0.0_dp
        real(dp), allocatable :: angles(:)
    end type report_t

contains

    subroutine evaluate(c, m, rep)
        type(case_t), intent(in) :: c
        type(msh_t), intent(in) :: m
        type(report_t), intent(out) :: rep
        real(dp), allocatable :: x(:), y(:), bx(:), by(:)
        integer, allocatable :: seg(:, :)
        real(dp) :: ax, ay, cx, cy, tx, ty, a2, b2, c2, sarea, gx, gy
        integer :: k, n

        n = case_npoint(c)
        allocate (bx(n), by(n))
        bx(:) = c%bdry_R(:) - c%R_hole
        by(:) = c%bdry_Z(:) - c%Z_hole
        allocate (x(m%npoint), y(m%npoint))
        x(:) = m%R(:) - c%R_hole
        y(:) = m%Z(:) - c%Z_hole

        rep%npoint = m%npoint
        rep%ntri = m%ntri
        rep%nseg = m%nseg
        rep%nseg_expected = n

        ! The Y flag forbids splitting boundary segments, so the input points
        ! must come back first and in place. The comparison is relative to the
        ! absolute coordinate magnitude, not to the translated one: a mesh file
        ! written with 16 significant digits at R ~ 1.7e5 cm cannot reproduce
        ! the input to better than ~1e-11 cm, while a Steiner point inserted on
        ! a boundary segment would be off by a whole edge length.
        rep%n_input_moved = 0
        if (m%npoint >= n) then
            do k = 1, n
                if (moved(x(k), bx(k), c%bdry_R(k)) .or. &
                    moved(y(k), by(k), c%bdry_Z(k))) then
                    rep%n_input_moved = rep%n_input_moved + 1
                end if
            end do
        else
            rep%n_input_moved = n - m%npoint
        end if

        call case_segments(c, seg)
        rep%n_segment_lost = count_lost_segments(seg, m)

        allocate (rep%angles(3*m%ntri))
        rep%min_angle = 180.0_dp
        rep%area = 0.0_dp
        rep%n_inverted = 0
        rep%n_outside = 0
        do k = 1, m%ntri
            ax = x(m%tri(1, k)); ay = y(m%tri(1, k))
            tx = x(m%tri(2, k)); ty = y(m%tri(2, k))
            cx = x(m%tri(3, k)); cy = y(m%tri(3, k))
            sarea = 0.5_dp*((tx - ax)*(cy - ay) - (ty - ay)*(cx - ax))
            if (sarea <= 0.0_dp) rep%n_inverted = rep%n_inverted + 1
            rep%area = rep%area + abs(sarea)
            a2 = (tx - cx)**2 + (ty - cy)**2
            b2 = (ax - cx)**2 + (ay - cy)**2
            c2 = (ax - tx)**2 + (ay - ty)**2
            rep%angles(3*k - 2) = vertex_angle(a2, b2, c2)
            rep%angles(3*k - 1) = vertex_angle(b2, a2, c2)
            rep%angles(3*k) = vertex_angle(c2, a2, b2)
            rep%min_angle = min(rep%min_angle, minval(rep%angles(3*k - 2:3*k)))
            gx = (ax + tx + cx)/3.0_dp
            gy = (ay + ty + cy)/3.0_dp
            if (in_loop(bx, by, 0, c%npt_inner, gx, gy) .or. &
                .not. in_loop(bx, by, c%npt_inner, c%npt_outer, gx, gy)) then
                rep%n_outside = rep%n_outside + 1
            end if
        end do

        rep%area_expected = loop_area(bx, by, c%npt_inner, c%npt_outer) &
                            - loop_area(bx, by, 0, c%npt_inner)
        rep%area_rel_err = abs(rep%area - rep%area_expected)/rep%area_expected
    end subroutine evaluate

    pure function moved(got, want, scale) result(shifted)
        real(dp), intent(in) :: got, want, scale
        logical :: shifted

        shifted = abs(got - want) > 1.0e-12_dp*max(1.0_dp, abs(scale))
    end function moved

    pure function vertex_angle(opposite2, first2, second2) result(deg)
        real(dp), intent(in) :: opposite2, first2, second2
        real(dp) :: deg, cosine

        cosine = (first2 + second2 - opposite2)/(2.0_dp*sqrt(first2*second2))
        deg = acos(max(-1.0_dp, min(1.0_dp, cosine)))*180.0_dp/PI
    end function vertex_angle

    function count_lost_segments(seg, m) result(lost)
        !! A segment survives only if it is both listed as a boundary segment
        !! and carried by a triangle edge -- FreeFem's border merge in
        !! scripts/extmesh.edp needs both.
        integer, intent(in) :: seg(:, :)
        type(msh_t), intent(in) :: m
        integer :: lost
        integer, allocatable :: mesh_edges(:, :), mesh_segs(:, :)
        integer :: k

        allocate (mesh_segs(2, m%nseg))
        do k = 1, m%nseg
            mesh_segs(:, k) = sorted_pair(m%seg(1, k), m%seg(2, k))
        end do
        allocate (mesh_edges(2, 3*m%ntri))
        do k = 1, m%ntri
            mesh_edges(:, 3*k - 2) = sorted_pair(m%tri(1, k), m%tri(2, k))
            mesh_edges(:, 3*k - 1) = sorted_pair(m%tri(2, k), m%tri(3, k))
            mesh_edges(:, 3*k) = sorted_pair(m%tri(3, k), m%tri(1, k))
        end do
        lost = 0
        do k = 1, size(seg, 2)
            if (.not. has_pair(mesh_segs, sorted_pair(seg(1, k), seg(2, k))) &
                .or. .not. has_pair(mesh_edges, sorted_pair(seg(1, k), seg(2, k)))) then
                lost = lost + 1
            end if
        end do
    end function count_lost_segments

    pure function sorted_pair(i, j) result(p)
        integer, intent(in) :: i, j
        integer :: p(2)

        p = [min(i, j), max(i, j)]
    end function sorted_pair

    pure function has_pair(list, p) result(found)
        integer, intent(in) :: list(:, :), p(2)
        logical :: found
        integer :: k

        found = .false.
        do k = 1, size(list, 2)
            if (list(1, k) == p(1) .and. list(2, k) == p(2)) then
                found = .true.
                return
            end if
        end do
    end function has_pair

    pure function loop_area(x, y, offset, n) result(a)
        real(dp), intent(in) :: x(:), y(:)
        integer, intent(in) :: offset, n
        real(dp) :: a
        integer :: k, nxt

        a = 0.0_dp
        do k = 1, n
            nxt = offset + modulo(k, n) + 1
            a = a + x(offset + k)*y(nxt) - y(offset + k)*x(nxt)
        end do
        a = 0.5_dp*abs(a)
    end function loop_area

    pure function in_loop(x, y, offset, n, px, py) result(inside)
        real(dp), intent(in) :: x(:), y(:), px, py
        integer, intent(in) :: offset, n
        logical :: inside
        integer :: k, prev

        inside = .false.
        prev = n
        do k = 1, n
            if ((y(offset + k) > py) .neqv. (y(offset + prev) > py)) then
                if (px < (x(offset + prev) - x(offset + k))* &
                    (py - y(offset + k))/(y(offset + prev) - y(offset + k)) &
                    + x(offset + k)) then
                    inside = .not. inside
                end if
            end if
            prev = k
        end do
    end function in_loop

    pure function report_ok(rep, min_angle_target, area_tol) result(ok)
        type(report_t), intent(in) :: rep
        real(dp), intent(in) :: min_angle_target, area_tol
        logical :: ok

        ok = rep%n_input_moved == 0 .and. rep%n_segment_lost == 0 &
             .and. rep%nseg == rep%nseg_expected &
             .and. rep%n_inverted == 0 .and. rep%n_outside == 0 &
             .and. rep%area_rel_err <= area_tol &
             .and. rep%min_angle >= min_angle_target
    end function report_ok

    subroutine print_report(rep, label, min_angle_target, area_tol)
        type(report_t), intent(in) :: rep
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: min_angle_target, area_tol

        write (*, '(a)') '--- '//trim(label)
        write (*, '(a, i0, a, i0, a, i0)') '  points   ', rep%npoint, &
            '   triangles ', rep%ntri, '   segments ', rep%nseg
        call flag('  boundary points unmoved', rep%n_input_moved == 0, rep%n_input_moved)
        call flag('  segments preserved     ', rep%n_segment_lost == 0, rep%n_segment_lost)
        call flag('  segment count          ', rep%nseg == rep%nseg_expected, &
                  rep%nseg - rep%nseg_expected)
        call flag('  orientation (ccw)      ', rep%n_inverted == 0, rep%n_inverted)
        call flag('  hole respected         ', rep%n_outside == 0, rep%n_outside)
        write (*, '(a, es10.3, a, es10.3, a)') '  area rel. error         ', &
            rep%area_rel_err, '  (tol ', area_tol, ')'
        write (*, '(a, f8.3, a, f6.2, a)') '  minimum angle            ', &
            rep%min_angle, ' deg  (target ', min_angle_target, ')'
    end subroutine print_report

    subroutine flag(text, ok, count)
        character(len=*), intent(in) :: text
        logical, intent(in) :: ok
        integer, intent(in) :: count

        if (ok) then
            write (*, '(a, a)') text, '  ok'
        else
            write (*, '(a, a, i0, a)') text, '  FAIL (', count, ')'
        end if
    end subroutine flag

end module bench_quality

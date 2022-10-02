{$N+,R-,F+,G+,X+,V-,E+,B+,A+}
uses	crt;

type    SURFACE = pchar;

const   VIDEO_BUFFER	: SURFACE = PTR($A000, 0);
	MAX_WIDTH	= 320;
        MAX_HEIGHT	= 200;
        MAX_SIZE	= MAX_WIDTH * MAX_HEIGHT;
        HALF_WIDTH	= MAX_WIDTH shr 1;
	HALF_HEIGHT	= MAX_HEIGHT shr 1;

var	Y_OFFSET	: array[0..MAX_HEIGHT-1] of longint;

procedure	vsync;
begin
	while port[$3DA] and 8 =  0 do ;
        while port[$3DA] and 8 <> 0 do ;
end;

function	surface_create: SURFACE;
var	srf	: SURFACE;
begin
        getmem(srf, MAX_SIZE);
        surface_create := srf;
end;

procedure	surface_destroy(var srf: SURFACE);
begin
	freemem(srf, MAX_SIZE);
end;

procedure	surface_flip(srf: SURFACE);
begin
        move(srf^, VIDEO_BUFFER^, MAX_SIZE);
end;

procedure	graph_start;
var	i	: longint;
begin
	for i := 0 to MAX_HEIGHT-1 do Y_OFFSET[i] := i * MAX_WIDTH;
	asm	mov	ax, 0013h
		int	10h
        end;
end;

procedure	graph_end; assembler;
asm	mov	ax, 0003h
        int	10h
end;

procedure       line_h(srf: SURFACE; x1, x2, y: integer; color: byte);
var	p	: SURFACE;
begin
	p := srf + Y_OFFSET[y] + x1;
        fillchar(p^, abs(x2-x1+1), color);
end;

procedure	line_v(srf: SURFACE; x, y1, y2: integer; color: byte);
var	p	: SURFACE;
	i	: integer;
begin
	p := srf + Y_OFFSET[y1] + x;
        for i := 0 to abs(y2-y1+1) do
        begin
        	p^ := char(color);
                inc(p, MAX_WIDTH);
        end;
end;

procedure	bard(srf: SURFACE; x, y, w, h: integer; color: byte);
var	p	: SURFACE;
	i	: integer;
begin
	p := srf + Y_OFFSET[y] + x;
        for i := 0 to h-1 do
        begin
		fillchar(p^, w, color);
                inc(p, MAX_WIDTH);
        end;
end;

const	MAP_WIDTH	= 24;
	MAP_HEIGHT	= 24;
        MAP_DIMMER	= 72;

type	WORLD		= array[0..MAP_WIDTH-1, 0..MAP_HEIGHT-1] of byte;

function	load_map(filename: string; var map: WORLD): boolean;
var	f	: TEXT;
	i, j	: integer;
begin
	assign(f, filename);
        {$I-}
        reset(f);
        {$I+}
        if ioresult <> 0 then
        begin
        	load_map := FALSE;
                exit;
        end;

        for i := 0 to MAP_WIDTH-1 do
	        for j := 0 to MAP_HEIGHT-1 do read(f, map[i, j]);

        close(f);
        load_map := TRUE;
end;

var	lh, ls, le, clr, x, y,
	xstep, ystep, mx, my	: longint;
	done, hit, side		: boolean;
	xp, yp, drx, dry, cam_x,
	px, py, ftime, xod, yod,
	xop, yop, mvspd, rtspd,
	xsided, ysided, dist,
	xdd, ydd, rdx, rdy	: single;
	off			: SURFACE;
	map			: WORLD;
        key			: char;
begin
        if not load_map('world.txt', map) then
        begin
                writeln('cannot load world');
                exit;
        end;

        graph_start;
	off   	:= surface_create;
        done  	:= FALSE;
	mvspd 	:= 0.3;	rtspd	:= 0.04;
	xp	:= 22;	yp	:= 12;
	drx	:= -1;	dry	:= 0;
	px	:= 0;	py	:= 0.66;
	repeat
		bard(off, 0, 0, MAX_WIDTH, HALF_HEIGHT, $7E);		{ ceiling }
		bard(off, 0, HALF_HEIGHT, MAX_WIDTH, HALF_HEIGHT, 19);	{ floor }

		for x := 0 to MAX_WIDTH-1 do
		begin
			cam_x 	:= 2.0 * x / MAX_WIDTH - 1;
			rdx 	:= drx + px * cam_x;
			rdy 	:= dry + py * cam_x;
			mx	:= trunc(xp);
			my	:= trunc(yp);

		       	if rdx = 0 then xdd := 1E6 else xdd := abs(1.0/rdx);
			if rdy = 0 then ydd := 1E6 else ydd := abs(1.0/rdy);

			if (rdx < 0) then
			begin
				xstep := -1;
				xsided := (xp - mx) * xdd;
			end
			else
			begin
				xstep := 1;
				xsided := (mx + 1.0 - xp) * xdd;
			end;
			if (rdy < 0) then
			begin
				ystep := -1;
				ysided := (yp - my) * ydd;
			end
			else
			begin
				ystep := 1;
				ysided := (my + 1.0 - yp) * ydd;
			end;

			hit := FALSE;
			while (not hit) do
			begin
				if(xsided < ysided) then
				begin
					xsided := xsided + xdd;
					inc(mx, xstep);
					side := FALSE;
				end
				else
				begin
					ysided := ysided + ydd;
					inc(my, ystep);
					side := TRUE;
				end;
				hit := (map[mx, my] > 0);
			end;

			if not side then dist := (xsided - xdd)
			else          	 dist := (ysided - ydd);

			if dist < 1E-4 then dist := 1E-4;
			lh := trunc(MAX_HEIGHT / dist);

			ls := -(lh shr 1) + HALF_HEIGHT;
			if (ls < 0) then ls := 0;
			le := +(lh shr 1) + HALF_HEIGHT;
			if (le >= MAX_HEIGHT) then le := MAX_HEIGHT - 1;

			case map[mx, my] of
			1:	clr := $50;
			2:	clr := $2B;
			3:	clr := $2F;
			4:	clr := $37;
                        5:	clr := $3C;
			else	clr := 0;
			end;
			if side then     if clr <> 0 then inc(clr, MAP_DIMMER);
                        if dist > 5 then if clr <> 0 then inc(clr, MAP_DIMMER);

			line_v(off, x, ls, le, clr);
		end;

		vsync;
		surface_flip(off);

		if keypressed then
		begin
			key := upcase(readkey);
                        done := key = #27;
			case key of
			'W':	begin
					if (map[trunc(xp + drx * mvspd), trunc(yp)] = 0) then xp := xp + drx * mvspd;
					if (map[trunc(xp), trunc(yp + dry * mvspd)] = 0) then yp := yp + dry * mvspd;
				end;
			'S':	begin
					if (map[trunc(xp - drx * mvspd), trunc(yp)] = 0) then xp := xp - drx * mvspd;
					if (map[trunc(xp), trunc(yp - dry * mvspd)] = 0) then yp := yp - dry * mvspd;
				end;
			'D':	begin
					xod    	:= drx;
					drx   	:= drx * cos(-rtspd) - dry * sin(-rtspd);
					dry   	:= xod * sin(-rtspd) + dry * cos(-rtspd);
					xop    	:= px;
					px	:= px  * cos(-rtspd) - py * sin(-rtspd);
					py 	:= xop * sin(-rtspd) + py * cos(-rtspd);
				end;
			'A':	begin
					xod	:= drx;
					drx	:= drx * cos(rtspd) - dry * sin(rtspd);
					dry	:= xod * sin(rtspd) + dry * cos(rtspd);
					xop	:= px;
					px	:= px  * cos(rtspd) - py * sin(rtspd);
					py	:= xop * sin(rtspd) + py * cos(rtspd);
				end;
			end;
		end;
	until done;
	surface_destroy(off);
	graph_end;
end.
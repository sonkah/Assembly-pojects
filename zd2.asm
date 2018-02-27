;Anna Baran
;Projekt laboratoryjny 2
;Kompresja RLE
.386
;.286
DATA SEGMENT	
	input			db	200 dup ("$")
	index1			dw	0
	offset1			dw	0
	uchwyt_input	dw	?
	dlugosc_bufora1	dw	0
	bufor1		db	10000 dup ("$")
	
	czy_piszemy		db	1											; domyslnie pisak opuszczony
	kat				dw	270
	dl_sciezki		dw	?
	czy_koniec_pliku db 0
	
	komun	db	10, 13, "otworz zapis done$"
	komun2  db  10, 13, "otworz odczyt done$" 
	komun3  db  10, 13, "zamknij done$"
	komun4  db  10, 13, "zapis do pliku done$"
	blad0	db	"Brak argomentow$"
	blad1	db	"Za malo argumentow$"
	blad2	db	"Za duzo argumentow$"
	blad3	db	"Wejscie powinno miec forme: '[-d] plik_wejsciowy plik_wyjsciowy'. $"
	blad4	db	"Za dluga nazwa pliku wejsciowego lub wyjsciowego. $"
	blad5	db	"Zly format pliku wejsciowego lub wyjsciowego. $"
	blad6	db	"Blad otwierania pliku wejsciowego. $"
	blad_instr	db	"Blad. Nieznana instrukcja.$"
	bladx	db	"Blad! $"
	
	xd		db	 "kicia $$"
	
	_180_		dw	180d	; wartość 180 potrzebna przy zamianie stopni na radiany
	_2_		dw	2	; wartość 2 potrzebna do mnożenia przez dwa
	_0_		dw	0	; wartość 2 potrzebna do mnożenia przez dwa
	x_beg		dw	160	; stała, początkowa wsp. x pozycji żółwia
	y_beg		dw	100	; stała, początkowa wsp. y pozycji żółwia
	len		dw	80	; długość odcinka
	xp		dd	160	; wsp. X początku odcinka
	yp		dd	100	; wsp. Y początku odcinka
	xk		dd	?	; wsp. X końca odcinka
	yk		dd	?	; wsp. Y końca odcinka
	tmp_integer	dw	?	; tymczasowe miejsce do konwersji float -> int
	D_Di		dd	?
	D_y		dd	?
	D_x		dd	?
	m_y		dd	?
	m_x		dd	?
	
	
DATA ENDS

STOS1 SEGMENT STACK
	dw 200 dup(?)   
	wstosu	dw ?
STOS1 ENDS



CODE SEGMENT use16
start:
;---------------------------------------------------------------------------------------------------------------------------
;inicajlizacja stosu
	mov ax, seg stos1
	mov ss, ax
	mov sp, offset wstosu
	
;zapamietanie segmentu danych w ds
	mov ax, seg DATA
	mov ds, ax		
;---------------------------------------------------------------------------------------------------------------------------

	call parser
	call spr_arg
	call otworz_odczyt												; dziala?
	call rysowanie
;	mov	bx, word ptr ds:[uchwyt_input]
;	mov cl, byte ptr ds:[kat]
;	mov dx, offset xd
;	xx:
;	call wypisz
;	loop xx
	call zamknij_plik
	jmp koniec
	
;---------------------------------------------------------------------------------------------------------------------------
;PARSER
;Wejście: 
; linia polecen
;Wyjście: 
; kolejne argumenty w INPUT odzielone znakiem $$, ostatni zakończony na 0  (powinien być tylko 1 arg)
; liczba argumentow w bl
; offset pierwszego argumentu w offset1
;---------------------------------------------------------------------------------------------------------------------------
parser:
	push ax
	push cx
	push dx
	
	xor cx, cx
	xor bx, bx														; w bl trzymamy liczbe argumentow
	mov	cl, byte ptr es:[80h]										; mamy liczbe znakow w cl
	cmp cl, 0d														; czy nie ma arg
	je	err0
	
	mov si, 82h														; ustawiam si na początek buforu,
	mov di, offset input
	
	zczytywanie:					
		jmp biale													; zjada biale znaki, 
		biale_powrot:												; jeżeli jest drugi argument to BIALE wroci tutaj
		inc bl														; bl - LICZNIK ARGUMENTÓW
		mov word ptr ds:[offset1],di								; początek argumentu zapisuje do offset1 - jeżeli jest wiecej niz 1 arg to program i tak nie zadziała
		zapis:														; zapis wykona sie tyle razy ile znakow wpisano (informacja ile ich bylo jest w cx)
			mov al, byte ptr es:[si]
			cmp al, 013d	;enter									; czy koniec? 
			je	koniec_zapisu										; jeżeli jest enter to procedura biale go wykryje
			cmp al, 032d ;spacja
			je 	koniec_zapisu
			cmp al, 009d	;tab
			je 	koniec_zapisu
			
			mov byte ptr ds:[di],al									; jezeli wszystko dobrze - przenosimy do input
			inc si
			inc di
		loop zapis
		koniec_zapisu:												; kończy zapis jednego argumentu

		mov byte ptr ds:[di], 0										; dodaje 0 na koncu nazwy pliku do otwarcia
		inc di
		inc di														; kolejne argumenty oddzielone będą znakami $$
	jmp zczytywanie													; kontynuuje zczytywanie dopóki BIALE nie wykryje entera. wtedy skoczy do koniec prsera
	koniec_parsera:
	pop dx
	pop cx
	pop ax
ret
	
;--------------------------------------------------------------------------------
biale:													; biale znaki na początku
		mov al, byte ptr es:[si]						; do al znak z wiersza polecień
		cmp al,032d          							; sprawdzamy czy spacja
		je	nastepny
		cmp al,009d          							; spr tab
		je	nastepny	
		cmp al, 013d									; jezeli enter to wychodzimy
		je koniec_parsera								; gdy na początku nie ma bialych znakow wracamy
jmp biale_powrot
	nastepny:
		inc si											; przesuwamy si na następny
		dec cl											; znakow będzie mniej	
	jmp biale
	

;----------------------------------------------------------------------------------------------------------------------------------------
;SPRAWDZANIE POPARAWNOSCI ARGUMENTOW
;Wejście: 
; 
; ilosc argumentow w bl
; argumenty w tablicy input

;Wyjście: 
;----------------------------------------------------------------------------------------------------------------------------------------
spr_arg:											; sprawdza czy jest 1 arg. LICZNIK W BL!
	pusha
	cmp bl, 1d
	ja	err2											; jezeli wiecej niz jeden arg to blad
	call spr_ilosc_znakow								
	popa
ret

spr_ilosc_znakow:										; sprawdza czy nazwa pliku nie ma wiecej niz 12 znakow
	pusha												; w si zostaje zapamiętany offset znaku 4 od końca, potrzebne w spr_czy_bmp
	mov	si, word ptr ds:[offset1]
	xor bx, bx
	dec bl
	dec si
	p1:
		inc si
		inc bl
		cmp byte ptr ds:[si], '$'						; petla zliczajaca znaki dopoki nie natrofi na $
		jne p1
	cmp bl, 12d											; jezeli nazwa ma wiecej niz 12 znakow to blad
	ja	err4
	
	popa

ret		
;---------------------------------------------------------------------------------------------------------------------------
;OTIWERANIE PLIKU DO ODCZYTU
;Wejście: 
;Wyjście: 
; plik zostal otwarty
; uchwyt do pliku w offset input
;---------------------------------------------------------------------------------------------------------------------------
otworz_odczyt:
	pusha
	mov dx, word ptr ds:[offset1]
	xor ax, ax
	mov ah, 03dh
	int 21h
	jc	err6
	mov word ptr ds:[uchwyt_input], ax
	
	mov dx, offset komun2
	call wypisz
	popa
ret


zamknij_plik:											; zamykanie pliku, offset nazwy trzeba dać do bx?
	pusha
	mov	bx, word ptr ds:[uchwyt_input]
	mov	ah,03eh
	int	21h
	jc errx						; DO POPRAWY!!!!!!!!!!
	mov dx, offset komun3
	call wypisz
	popa
ret

;--------------------------------------------------------------------------------------------------------------------------
;GETCHAR
;Wejście: 
;	offset początku bufora
;	aktualne miejsce, na którym się znajdujemy w buforze (przesunięcie)
;	dlugosc bufora
;Wyjście: 
;	kolejny znak zbufora w al
;	inc aktualne miejsce
;	flaga czy koniec pliku
;--------------------------------------------------------------------------------------------------------------------------
getchar:
	mov ax, word ptr ds:[dlugosc_bufora1]
	cmp word ptr ds:[index1], ax
	jne	gc
		call bufor
		cmp word ptr ds:[dlugosc_bufora1], 0
		jne gc
		mov byte ptr ds:[czy_koniec_pliku], 1
	ret
	gc:	
	push bx
		mov bx, word ptr ds:[index1]
		mov al, byte ptr ds:[bufor1 + bx]
	pop bx
	
	inc word ptr ds:[index1]
	mov byte ptr ds:[czy_koniec_pliku], 0
ret

;--------------------------------------------------------------------------------------------------------------------------

;ZALADOWANIE NOWEGO CIAGU ZNAKOW DO BUFORA
;Wejście: 
;	offset początku bufora
;	uchwyt do pliku
;
;Wyjście: 
;	załadowany nowy bufor
;	miejsce w buforze = 0 (index1)
; 	nowa dlugosc bufora

;--------------------------------------------------------------------------------------------------------------------------
bufor:
	push dx
	push cx
	push bx
		
	mov	dx, offset bufor1
	mov	bx, word ptr ds:[uchwyt_input]	
	mov	cx, 10000	
	
	mov	ah, 3fh
	int	21h
	jc errx
	
	mov word ptr ds:[dlugosc_bufora1], ax
	mov word ptr ds:[index1], 0
	pop bx
	pop cx
	pop dx
ret
;--------------------------------------------------------------------------------------------------------------------------
;Wejscie:
; 
;Wyjście:
; 
;--------------------------------------------------------------------------------------------------------------------------
rysowanie:
	push	cx
	push	si
	
	finit
	fild	word ptr ds:[x_beg]
	fst		dword ptr ds:[xp]
	fild	word ptr ds:[y_beg]
	fst		dword ptr ds:[yp]
	
	mov	ax, 13h
	int	10h		; przejście do trybu graficznego
	
	mov	ax, 0A000h
	mov	es, ax	; ustawiam segment na odpowiedni dla trybu graf. 13h
	call getchar
	petla_krokow:
		cmp	al, 'r'
		je	rotacja
		cmp	al, 'm'
		je	ruch
		cmp	al, 'u'
		je	podnies
		cmp al, 'd'
		je	opusc
		call err_instr
		nastepny_krok:
		call getchar
		cmp  byte ptr ds:[czy_koniec_pliku], 1
	jne	petla_krokow
	
	
	xor ah, ah
	int 16h		; czekanie na naciśnięcie przycisku
	mov ax, 3
	int 10h		; powrót do trybu tekstowego
	
	pop	si
	pop	cx
ret

;rysuj:
;	pusha
;	
;	call getchar 
;	cmp ds:[czy_koniec_pliku], 1
;	je	koniec_pliku
;	cmp	al, 032d													; jezeli jest spacaja to przeskocz na następny
;	je	nastepny_krok
;	cmp	al, 'r'
;	je	rotacja
;	cmp al, 'm'
;	je	ruch
;	cmp al, 'u'
;	je	podnies
;	cmp	al, 'd' 
;	je	opusc
;	jmp err_instr
;	nastepny_krok:
;;	popa
;	jmp rysuj
;	koniec_pliku:
;	popa
;ret

;--------------------------------------------------------------------
opusc:
	mov byte ptr ds:[czy_piszemy], 1
jmp nastepny_krok

podnies:
	mov byte ptr ds:[czy_piszemy], 0
jmp nastepny_krok

rotacja:
;call p_rotacja
	push ax
	push bx
	push dx
	
	call	zamien_ciag_na_liczbe

	mov	ax, dx	; wrzucam liczbę do ax
	xor	dx, dx	; zeruje dx bo będzie on brany pod uwagę przy dzieleniu
	add	ax, word ptr ds:[kat]	; dodaje do obecnego kąta
	mov	bx, 360d
	div	bx				; modulo 360
	mov	word ptr ds:[kat], dx	; uaktualniam kąt
	
	pop	dx
	pop	bx
	pop	ax
	
jmp nastepny_krok


ruch:
	push	ax
	push	bx
	push	dx
	push	di
	
	call zamien_ciag_na_liczbe
	mov	word ptr ds:[dl_sciezki] ,dx	; zapisuję długość
	
	call rysowanie_linii		; rysowanie linii
	
;	call get_char	; pobieram line feed żeby drawing_loop weszła w nową linię
	
	pop	di
	pop	dx
	pop	bx
	pop	ax
jmp nastepny_krok


zamien_ciag_na_liczbe:
	push	ax
	push	bx
	push	di
	
	xor	ax, ax
	xor	bx, bx
	biale_znaki_pocz:
	call	getchar
	cmp	al, 32d	
	je biale_znaki_pocz
	jne pomin_1_getchar
	wczytaj_liczbe:
		call	getchar
;		cmp	al, 13d				; jeśli carrige return to koniec lini i koniec wczytywania integera
;		je	koniec_wczytywania
		cmp	al, 32d				
		je	koniec_wczytywania
		
		pomin_1_getchar:
		
		cmp	al, 48d
		jae	prawie_ok
			call err_instr
		prawie_ok:
		cmp	al, 57d
		jbe	ok
			call err_instr
		ok:
		sub	al, 48d	
		push ax								; odkładam na stos żeby odwrócić potem kolejność
		inc	bx								; ile cyfr ma liczba
	jmp	wczytaj_liczbe
	
	koniec_wczytywania:
	
	xchg cx, bx	; wrzucam do cx ilość wczytanych cyfr (będzie pętla), a stare cx zachowuję w bx
	xor	bx, bx
	mov	di, 1d	; to będzie czynnik z kolejnymi potęgami 10
	zamiana:
		pop	ax				; ściągam kolejną cyfrę
		mul	di				; mnożę razy odpowiednią potęgę 10
		add	bx, ax
		imul di, 10d	; kolejna potęga 10
	loop zamiana
	
	mov dx,bx
;	xchg	cx, bx	; przywracam stary cx
	
	pop	di
	pop	bx
	pop	ax
ret


rysowanie_linii:
	push	cx
	push	si
	push	di
	push	bp
	push	es
	
	call	find_end_coordinates
	call	check_case
	
	finit
	fld	dword ptr ds:[D_y]
	fimul	word ptr ds:[_2_]
	fsub	dword ptr ds:[D_x]
	fst	dword ptr ds:[D_Di]	; w [D_Di] mam początkową wartość D_Di
	
	finit
	fld	dword ptr ds:[yp]
	fist	word ptr ds:[tmp_integer]
	mov	di, word ptr ds:[tmp_integer]
	imul	di, 320d
	fld	dword ptr ds:[xp]
	fist	word ptr ds:[tmp_integer]
	add	di, word ptr ds:[tmp_integer]		; wczytuję pozycję żółwia do rejestru DI
	
	fld	dword ptr ds:[D_x]
	fist	word ptr ds:[tmp_integer]
	mov	cx, word ptr ds:[tmp_integer]	; licznik <- D_X
	
	main_loop:
		finit
		fld	dword ptr ds:[D_Di]
		fist	word ptr ds:[tmp_integer]
		mov	ax, word ptr ds:[tmp_integer]
		cmp	ax, 0d
		jl	less_than_zero
			add	di, si
			add	di, bp	; w DI mam jednowymiarową współrzędną piksela do zapalenia
			
			finit
			fld	dword ptr ds:[D_y]
			fsub	dword ptr ds:[D_x]
			fimul	word ptr ds:[_2_]
			fadd	dword ptr ds:[D_Di]
			fst	dword ptr ds:[D_Di]
			
			jmp	goto_drawing_pixel
		less_than_zero:
			add	di, si	; w DI mam jednowymiarową współrzędną piksela do zapalenia
			finit
			fld	dword ptr ds:[D_y]
			fimul	word ptr ds:[_2_]
			fadd	dword ptr ds:[D_Di]
			fst	dword ptr ds:[D_Di]
			
		goto_drawing_pixel:
		
		cmp	byte ptr ds:[czy_piszemy], 1	; sprawdzam flagę pisaka, jak podniesiona to nie koloruję
		jne	PenUP_DoNotPaint
			mov	byte ptr es:[di], 15d	; koloruję piksel na biało
		PenUP_DoNotPaint:
	loop main_loop
	
	mov	eax, dword ptr ds:[xk]		; |
	mov	dword ptr ds:[xp], eax		; |
	mov	eax, dword ptr ds:[yk]		; | => punkt końcowy staje się nowym punktem początkowym
	mov	dword ptr ds:[yp], eax		; |
	
	pop	es
	pop	bp
	pop	di
	pop	si
	pop	cx
ret

find_end_coordinates:
	push	eax
	push	edx
	
	cmp	word ptr ds:[kat], 90d
	jne	not_90_deg
		mov	eax, dword ptr ds:[xp]
		mov	dword ptr ds:[xk], eax
		finit
		fld	dword ptr ds:[yp]
		fiadd	word ptr ds:[len]
		fst	dword  ptr ds:[yk]
		jmp	coordinates_found
	not_90_deg:
	cmp	word ptr ds:[kat], 270d
	jne	not_270_deg
		mov	eax, dword ptr ds:[xp]
		mov	dword ptr ds:[xk], eax
		finit
		fld	dword ptr ds:[yp]
		fisub	word ptr ds:[len]
		fst	dword  ptr ds:[yk]
		jmp	coordinates_found
	not_270_deg:

	finit
	fldpi				; ładuję pi
	fidiv	word ptr ds:[_180_]	; w st(0) mam pi/180
	fimul	word ptr ds:[kat]	; w st(0) mam pi/180 * kąt w radianach
	
	fldz			; st(0) = 0.0, st(1) = alpha
	fadd	st(0), st(1); st(0) = alpha, st(1) = alpha, bo alpha przyda się później
	
	; liczę xk
	fcos		; w st(0) mam cos(alpha)
	fimul word ptr ds:[len]
	fadd	dword ptr ds:[xp]	; w st(0) mam obliczony xk
	fst	dword ptr ds:[xk]	; zapisuję xk
	
	; liczę yk
	fsub	dword ptr ds:[xp]	; st(0) = dx = xk-xp, st(1) = alpha ciągle
	fxch	st(1)			; swap -> st(0) = alpha, st(1) = dx
	fptan				; liczę tan(alpha), st(0) = 1.0, st(1) = tangens, st(2)= dx
	fxch	st(2)			; niepotrzebna 1 idzie do st(2)
	fmul	st(0), st(1)
	fadd	dword ptr ds:[yp]	; w st(0) mam obliczony yk
	fst	dword ptr ds:[yk]	; zapisuję yk

	coordinates_found:
	
	pop	edx
	pop	eax
ret



check_case:
	push	ax
	
	
	mov	ax, word ptr ds:[kat]
	cmp	ax, 45d
	jb	first_case	
	cmp	ax, 90d
	jb	second_case	
	cmp	ax, 135d
	jb	third_case	
	cmp	ax, 180d
	jb	fourth_case	
	cmp	ax, 225d
	jb	fifth_case	
	cmp	ax, 270d
	jb	sixth_case	
	cmp	ax, 315d
	jb	seventh_case	
	jmp	eight_case	
	
	first_case:
		finit
		fld	dword ptr ds:[xk]	
		fsub	dword ptr ds:[xp]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[yk]	
		fsub	dword ptr ds:[yp]
		fst	dword ptr ds:[D_y]
		mov	si, 1d
		mov	bp, 320d
		jmp	case_checked
	second_case:
		finit
		fld	dword ptr ds:[yk]	
		fsub	dword ptr ds:[yp]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[xk]	
		fsub	dword ptr ds:[xp]
		fst	dword ptr ds:[D_y]
		mov	si, 320d
		mov	bp, 1d
		jmp	case_checked
	third_case:
		finit
		fld	dword ptr ds:[yk]	
		fsub	dword ptr ds:[yp]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[xp]	
		fsub	dword ptr ds:[xk]
		fst	dword ptr ds:[D_y]
		mov	si, 320d
		mov	bp, (-1d)
		jmp	case_checked
	fourth_case:
		finit
		fld	dword ptr ds:[xp]	
		fsub	dword ptr ds:[xk]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[yk]	
		fsub	dword ptr ds:[yp]
		fst	dword ptr ds:[D_y]
		mov	si, (-1d)
		mov	bp, 320d
		jmp	case_checked
	fifth_case:
		finit
		fld	dword ptr ds:[xp]	
		fsub	dword ptr ds:[xk]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[yp]	
		fsub	dword ptr ds:[yk]
		fst	dword ptr ds:[D_y]
		mov	si, (-1d)
		mov	bp, (-320d)
		jmp	case_checked
	sixth_case:
		finit
		fld	dword ptr ds:[yp]	
		fsub	dword ptr ds:[yk]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[xp]	
		fsub	dword ptr ds:[xk]
		fst	dword ptr ds:[D_y]
		mov	si, (-320d)
		mov	bp, (-1d)
		jmp	case_checked
	seventh_case:
		finit
		fld	dword ptr ds:[yp]
		fsub	dword ptr ds:[yk]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[xk]	
		fsub	dword ptr ds:[xp]
		fst	dword ptr ds:[D_y]
		mov	si, (-320d)
		mov	bp, 1d
		jmp	case_checked
	eight_case:
		finit
		fld	dword ptr ds:[xk]	
		fsub	dword ptr ds:[xp]
		fst	dword ptr ds:[D_x]
		fld	dword ptr ds:[yp]	
		fsub	dword ptr ds:[yk]
		fst	dword ptr ds:[D_y]
		mov	si, 1d
		mov	bp, (-320d)
	
	case_checked:
	
	pop	ax
ret
;--------------------------------------------------------------------------------------------------------------------------
err0:													;brak
	mov dx,offset blad0
	call wypisz
	jmp koniec

err1:													; za malo
	mov dx,offset blad1
	call wypisz
	jmp koniec

err2:													; za duzo
	mov dx,offset blad2
	call wypisz
	jmp koniec

err3:													; zle rzeczy na wejsciu
	mov dx,offset blad3
	call wypisz
	jmp koniec

err4:													; za dluga nazwa pliku
	mov dx,offset blad4
	call wypisz
	jmp koniec

err5:													; zly format pliku ma byc .bmp
	mov dx,offset blad5
	call wypisz
	jmp koniec
err6:
	mov dx,offset blad6									; nie udalo sie otworzyc pliku
	call wypisz
	jmp koniec
	
errx:
	mov dx,offset blad6									; nie udalo sie otworzyc pliku
	call wypisz
	jmp koniec

err_instr:
	
	wypisz:
	mov ah, 9h
	int 21h
ret


koniec:	
	mov ah, 04ch
	int 21h
	
CODE ENDS
END start

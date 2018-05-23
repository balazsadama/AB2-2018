-- Írjunk tárolt eljárást, mellyel egy új filmre vonatkozó információkat vezethetünk fel az
-- adatbázisba! A tárolt eljárás paraméterei: @pFilmCim, @pKoltseg, @pMegjEv, @pStudioNev,
-- @pSzineszNev, @pSzulDatum, @pMufajNev! Fontos! Egyidőben több felhasználó is végezhet
-- módosításokat az adatbázison! Tehát: tranzakció nélkül nem elfogadható a feladat!

GO
CREATE PROCEDURE UjFilm @pFilmCim varchar(30), @pKoltseg int, @pMegjEv int, @pStudioNev varchar(30),
@pSzineszNev varchar(30), @pSzulDatum date, @pMufajNev varchar(30)
as begin
set transaction isolation level serializable
begin transaction

-- a.Ellenőrizzük, hogy létezik-e ugyanolyan című film, melynek megjelenési éve is azonos
-- (@pFilmCim, @pMegjEv). Ha igen, a visszatérítési érték 4 legyen.  Ellenkező esetben,
-- ellenőrizzük, hogy léteznek-e az adatbázisban a paraméterként megadott további információk
-- és ahol szükséges, szúrjuk be a megadott adatokat a Studiok és Mufajok táblákba, majd
-- folytassuk a b.) alponttal.

if (select FilmID from Filmek where FilmCim = @pFilmCim and MegjEv = @pMegjEv) is not null
begin
	commit
	return 4
end

declare @studioid int = (select StudioID from Studiok where StudioNev = @pStudioNev)
if @studioid is null
begin
	set @studioid = (select max(StudioID) from Studiok) + 1
	insert into Studiok values (@studioid, @pStudioNev, null)
	if @@ERROR <> 0 begin rollback return end
end

declare @mufajid int = (select MufajID from Mufajok where MufajNev = @pMufajNev)
if @mufajid is null
begin
	set @mufajid = (select max(MufajID) from Mufajok) + 1
	insert into Mufajok values (@mufajid, @pMufajNev)
	if @@ERROR <> 0 begin rollback return end
end


-- b.Ellenőrizzük, hogy az adott műfajban (@pMufajNev) az adott stúdióban (@pStudioNev)  az
-- elmúlt másfél évben forgattak-e több, mint 50 új filmet. Ha igen, akkor a visszatérítési
-- érték legyen 3. Ellenkező esetben ellenőrizzük, hogy az adott színész (@pSzineszNev,
-- @pSzulDatum) filmjeinek összköltsége kevesebb-e, mint 5 millió euró. Ha kevesebb, akkor
-- a visszatérítési érték legyen 0, emellett ekkor szúrjunk be egy sort a Filmek és Szerepel
-- táblákba. Ellenkező esetben, folytassuk a c.) alponttal.


-- meg kell egy datediff h ne legyen eltelve tobb, mint masfel ev
if (select count(distinct FilmID) from Filmek where MufajID = @mufajid
												and StudioID = @studioid
												and DATEDIFF(Y, getdate(), MegjEv) < 2) < 50
begin
	rollback
	return 3
end


declare @szineszFilmjeinekKoltsege INT
set @szineszFilmjeinekKoltsege = (select count(f.Koltseg) from Filmek f, Szineszek szi, Szerepel sze
										where	f.FilmID = sze.FilmID
											and szi.SzineszID = sze.SzineszID
											and szi.SzineszNev = @pSzineszNev
											and szi.SzulDatum = @pSzulDatum )

if @szineszFilmjeinekKoltsege < 5000000
begin

	declare @filmID int = (select max(FilmID) from Filmek) + 1
	declare @szineszID int = (select SzineszID from Szineszek where SzulDatum = @pSzulDatum and SzineszNev = @pSzineszNev )
	insert into Filmek values(@filmID, @pFilmCim, @pKoltseg, @pMegjEv, @studioid, @mufajid, 0)
	if @@ERROR <> 0 begin rollback return end
	insert into Szerepel values (@szineszID, @filmID)
	if @@ERROR <> 0 begin rollback return end
	commit
	return 0
end



-- c. Keressünk olyan színészt, aki kevesebb, mint 20 filmben szerepelt és filmjeinek
-- összköltsége kevesebb, mint 5 millió euró és írassuk ki közülük az első három
-- legfiatalabbat! Ekkor a visszatérítési érték legyen 2
select SzineszID into #t1 from Szineszek szi
where (select count(distinct FilmID) from Szerepel sze where sze.SzineszID = szi.SzineszID) < 20
	and (select count(f.Koltseg) from Filmek f, Szerepel sze
										where	f.FilmID = sze.FilmID
											and szi.SzineszID = sze.SzineszID
											and szi.SzineszNev = @pSzineszNev
											and szi.SzulDatum = @pSzulDatum ) < 5000000
order by SzulDatum desc

select top 3 SzineszID from #t1
commit
return 2

end
GO

-- ha erdekel a tarolt eljaras visszateritesi erteke akkor:
-- declare @v int
-- exec @v = taroltEljaras ...

exec UjFilm 'Black Panther', 200000000, 2018, 'Marvel Studios', 'Chadwick Boseman', '1977-11-29', 'Action'
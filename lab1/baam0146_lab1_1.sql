--1. Írjunk tárolt eljárást, mely megadja a paraméterként megadott műfaj (@pMufajNev) és ugyancsak a
--paraméterként megadott  StudioNev (@StudioNev) esetén a filmek átlagköltségét! Ha nincs egyetlen olyan
--műfajú (@pMufajNev) film az adott studióban (@StudioNev) , akkor a @pOut kimeneti paraméter értékét
--állítsuk -2-re, ellenkező esetben 0-ra!
GO
CREATE PROCEDURE MufajStudio (@pMufajNev VARCHAR(30), @StudioNev VARCHAR(30), @pOut INT OUT)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @atlag INT

	SET @atlag = (
	SELECT	AVG(f.Koltseg)
	FROM	Mufajok m, Studiok s, Filmek f
	WHERE	m.MufajNev = @pMufajNev
		AND s.StudioNev = @StudioNev
		AND m.MufajID = f.MufajID
		AND f.StudioID = s.StudioID
	GROUP BY s.StudioID )

	IF (@atlag is null)
		SET @pOut = -2
	ELSE
		SET @pOut = 0
	
	PRINT @atlag
END
GO

DECLARE @kimenet int
EXEC MufajStudio 'Sci-fi', 'Gleichner-Okuneva', @pOut = @kimenet OUT
PRINT @kimenet

EXEC MufajStudio 'Comedy', 'Heathcote-Frami', @pOut = @kimenet OUT
PRINT @kimenet


--2.Írjunk  tárolt eljárást VAGY függvényt, melynek bemenő paraméterei:
--@pSzulHonap-int, @pKoltseg-int, @pDatum1-date, @pDatum2-date típusúak! A tárolt eljárás/függvény térítse
--vissza (függvény esetén-int típusú változóban, eljárás esetén-kimeneti paraméterben), hogy az adott hónapban
--(@pSzulDatum) született színészek, @pDatum1 és @pDatum2 között vetített filmje(i) hány százalékának költsége
--kisebb, mint @pKoltseg!
GO
CREATE PROCEDURE SzuletesVetites(@pSzulHonap INT, @pKoltseg INT, @pDatum1 DATE, @pDatum2 DATE, @pOut INT OUT)
AS
BEGIN
	SET NOCOUNT ON;
	SELECT DISTINCT	f.FilmID INTO #T1
	FROM	Vetites v, Szineszek szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID = f.FilmID
		AND f.FilmID = v.FilmID
		AND MONTH(szi.SzulDatum) = @pSzulHonap
		AND v.Datum BETWEEN @pDatum1 AND @pDatum2
	
	DECLARE @kedvezo INT
	SET @kedvezo = (
		SELECT	COUNT(f.FilmID)
		FROM	Filmek f, #T1
		WHERE	f.FilmID = #T1.FilmID
			AND f.Koltseg < @pKoltseg)

	DECLARE @osszes INT
	SET @osszes = (
		SELECT	COUNT(f.FilmID)
		FROM	Filmek f, #T1
		WHERE	f.FilmID = #T1.FilmID)

	PRINT (@kedvezo * 100.0 / @osszes)

	DROP TABLE #T1
END
GO

DECLARE @kimenet int
EXEC SzuletesVetites 1, 80000, '1950-01-01', '2018-12-21', @pOut = @kimenet OUT

EXEC SzuletesVetites 1, 70000, '2017-01-01', '2018-12-21', @pOut = @kimenet OUT


--3.(2p) Írjunk tárolt eljárást, melynek bemenő paraméterei: @pSzineszNev, @pStudiokSzama, @pAtlagKoltseg,
--@pVetitesSzam. Az eljárás segítségével adjuk meg az(oka)t a színész(eke)t, aki(k) teljesíti(k) a következő
--feltételeket:
--szerepeltek olyan műfajú filmekben, mint amelyekben @pSzineszNev nevű színész is szerepelt
--(ezeken kívül még más műfajú filmekben is szerepelhettek);
--kevesebb, mint @pStudiokSzama stúdióval dolgoztak együtt;
--azon filmek átlagköltsége, melyekben NEM szerepeltek kisebb, mint @pAtlagKoltseg;
--több, mint @pVetitesSzam alkalommal vetítik azon filmjeiket, melyekben szerepelnek és amelyek költsége
--a legkisebb.
GO
CREATE PROCEDURE Szineszekrol (@pSzineszNev VARCHAR(30), @pStudiokSzama INT, @pAtlagKoltseg INT, @pVetitesSzam INT)
AS
BEGIN
	SET NOCOUNT ON;
	-- azon mufajok, amilyen mufaju filmekben szerepelt @pSzineszNev nevu szinesz
	SELECT	DISTINCT MufajID INTO #T1
	FROM	Szineszek szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID = f.FilmID
		AND szi.SzineszNev = @pSzineszNev

	-- azon szineszek, akik szerepeltek ugyanolyan mufaju filmben, mint @pSzineszNev
	SELECT	DISTINCT szi.SzineszID INTO #T2
	FROM	Szineszek szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID = f.FilmID
		AND f.MufajID IN (SELECT MufajID FROM #T1)

	--azon szineszek, akik kevesebb, mint @pStudiokSzama studioval dolgoztak egyutt
	SELECT	szi.SzineszID INTO #T3
	FROM	#T2 szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID = f.FilmID
	GROUP BY szi.SzineszID
	HAVING	COUNT(DISTINCT f.StudioID) < @pStudiokSzama

	-- azon szineszek, ahol azon filmek átlagköltsége, melyekben NEM szerepeltek kisebb, mint @pAtlagKoltseg;
	SELECT	szi.SzineszID into #T4
	FROM	#T3 szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID != f.FilmID
	GROUP BY szi.SzineszID
	HAVING	AVG(f.Koltseg) < @pAtlagKoltseg

	-- több, mint @pVetitesSzam alkalommal vetítik azon filmjeiket, melyekben szerepelnek

	-- szineszid + legolcsobb filmjenek koltsege
	SELECT	szi.SzineszID, MIN(Koltseg) LegolcsobbKoltsege into #T5
	FROM	#T4 szi, Szerepel sze, Filmek f
	WHERE	szi.SzineszID = sze.SzineszID
		AND		sze.FilmID = f.FilmID
	GROUP BY szi.SzineszID

	-- szineszid + legolcsobb filmjenek id-ja
	SELECT	lo.SzineszID, f.FilmID into #T6
	FROM	Szerepel sze, Filmek f, #T5 lo
	WHERE	lo.SzineszID = sze.SzineszID
		AND sze.FilmID = f.FilmID
		AND f.Koltseg =	lo.LegolcsobbKoltsege
	
	-- szineszid + legolcsobb filmjenek vetitesi szama (amely nagyobb mint @pVetitesSzam)
	SELECT	szi.SzineszID into #T7
	FROM	#T6 szi, Szerepel sze, Filmek f, Vetites v
	WHERE	szi.SzineszID = sze.SzineszID
		AND sze.FilmID = szi.FilmID
		AND v.FilmID = szi.FilmID
	GROUP BY szi.SzineszID
	HAVING	COUNT(DISTINCT v.VetitesID) > @pVetitesSzam 


	IF EXISTS (SELECT * FROM #T7)
      BEGIN 
        SELECT * FROM #T7
      END 
    ELSE
      BEGIN
        RAISERROR('Nincs ilyen szinesz', 1, 1)
      END


	DROP TABLE #T1
	DROP TABLE #T2
	DROP TABLE #T3
	DROP TABLE #T4
	DROP TABLE #T5
	DROP TABLE #T6
	DROP TABLE #T7
END
GO


EXEC Szineszekrol 'Rozella Willcot', 2, 58000, 1
EXEC Szineszekrol 'Rozella Willcot', 1, 68000, 3


--4.Írjunk tárolt eljárást, melynek bemeneti paramétere: @pDatum date típusú! A tárolt eljárás segítségével
--írassuk ki azon filme(k) címét, amelye(ke)t a legkevesebbszer vetítenek a paraméterként megadott dátumon!
--Megj. Lehetséges, hogy van olyan film, amelyet egyszer sem vetítenek az adott dátumon! Ez esetben a kimeneti
--paraméter (@pOut-int típusú) értékét állítsuk -1-re, ellenkező esetben a kimeneti paraméter értéke legyen a
--feltételnek eleget tevő film(ek) átlagköltsége!
GO
CREATE PROCEDURE FilmekDatumon(@pDatum DATE, @pOut INT OUT)
AS
BEGIN
	SET NOCOUNT ON;
	-- azon filmek id-ja, amelyeket @pDatum datumon vetitenek
	SELECT	DISTINCT FilmID INTO #T1
	FROM	Vetites
	WHERE	Datum = @pDatum
	
	IF (SELECT COUNT(DISTINCT FilmID) FROM Filmek) != (SELECT COUNT(FilmID) FROM #T1)
	BEGIN
		SET @pOut = -1
	END
	ELSE
	BEGIN
		SELECT	f.FilmID, COUNT(DISTINCT v.VetitesID) AS Hanyszor INTO #T2
		FROM	#T1 f, Vetites v
		WHERE	f.FilmID = v.FilmID
		GROUP BY f.FilmID

		SELECT	t.FilmID INTO #T3
		FROM	#T2 t, Filmek f
		WHERE	t.FilmID = f.FilmID
			AND Hanyszor = (SELECT MIN(Hanyszor) FROM #T2)

		SET @pOut = (SELECT AVG(Koltseg) FROM Filmek f, #T3 t WHERE t.FilmID = f.FilmID)
		SELECT FilmCim FROM Filmek f, #T3 t WHERE f.FilmID = t.FilmID

		DROP TABLE #T2
		DROP TABLE #T3
	END

	DROP TABLE #T1
END
GO

DECLARE @kimenet int
EXEC FilmekDatumon '2016-11-07', @pOut = @kimenet OUT
print @kimenet


--5. a. Hozzunk létre egy új táblát: FilmekKoltseg_Log(ID, Idopont, Muvelet, FilmID, FilmCim, RegiKoltseg, UjKoltseg)
CREATE TABLE FilmekKoltseg_Log(
	ID			INT NOT NULL,
	FilmID		INT FOREIGN KEY REFERENCES Filmek(FilmID) DEFAULT NULL,
	FilmCim		VARCHAR(50),
	Idopont		DATETIME,
	Muvelet		VARCHAR(50),
	RegiKoltseg	INT,
	UjKoltseg	INT
)

--b. Oldjuk meg, hogy a Filmek táblából való törlés esetén a FilmekKoltseg_Log tábla FilmID mezőjének értéke NULL-ra módosuljon!
GO
CREATE TRIGGER TorlesFilmekbol ON Filmek INSTEAD OF DELETE AS
BEGIN
	SET NOCOUNT ON;
	UPDATE	FilmekKoltseg_Log
	SET		FilmID = NULL
	WHERE	FilmID = (SELECT FilmID FROM DELETED)

	DELETE FROM Filmek WHERE FilmID IN (SELECT FilmID FROM DELETED)
END
GO

--c. Írjunk UPDATE triggert, mely a Filmek tábla Koltseg mezőjének módosításakor beszúr egy új
--sort a FilmekKoltseg_Log táblába. Az időpont legyen a módosítás időpontja, művelet szövege:
--‘koltseg növelése’ vagy ‘koltseg csökkentése’, Regikoltseg-régi érték, Ujkoltseg-új érték.
GO
CREATE TRIGGER ModositasFilmekben ON Filmek AFTER UPDATE AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @regiKoltseg INT, @ujKoltseg INT, @muvelet VARCHAR(50),
		@filmID INT, @filmCim VARCHAR(50), @ujID INT, @lastID INT

	SET @regiKoltseg = (SELECT Koltseg FROM deleted)
	SET @ujKoltseg = (SELECT Koltseg FROM inserted)

	IF @regiKoltseg > @ujKoltseg
		SET @muvelet = 'koltseg csokkentese'
	ELSE
		SET @muvelet = 'koltseg novelese'
	
	IF not exists (SELECT * FROM FilmekKoltseg_Log)
	BEGIN
		SET @ujID = 1
	END
	ELSE
	BEGIN
		SET @lastID = (SELECT MAX(ID) FROM FilmekKoltseg_Log)
		SET @ujID = @lastID + 1
	END
	

	SET @filmID = (SELECT FilmID FROM deleted)
	SET @filmCim = (SELECT FilmCim FROM deleted)

	INSERT INTO FilmekKoltseg_Log(ID, FilmID, FilmCim, Idopont, Muvelet, RegiKoltseg, UjKoltseg)
		VALUES (@ujID, @filmID, @filmCim, GETDATE(), @muvelet, @regiKoltseg, @ujKoltseg)
END
GO


insert into filmek(FilmID, FilmCim, Koltseg, MegjEv, StudioID, MufajID)
values (30, 'Avengers', 2000000, 2016, 5, 1)

update Filmek
set Koltseg = 650000
where FilmID = 30

update Filmek
set Koltseg = 1750000
where FilmID = 30

delete from filmek where filmid = 30

select * from FilmekKoltseg_Log

--1. Írjunk függvényt, melynek bemenő paraméterei: @pSzineszNev, @pMufajNev! A függvény egy
--táblában térítse vissza azon film(ek) címét, költségét és stúdióját, mely(ek)ben a
--paraméterként megadott színész szerepel és rendelkezik a megadott műfajjal!

GO
CREATE FUNCTION SzineszMufaj (@pSzineszNev VARCHAR(50), @pMufajNev VARCHAR(50))
RETURNS TABLE AS
RETURN
(
SELECT	f.FilmCim, f.Koltseg, f.StudioID
FROM	Filmek f, Mufajok m, Szerepel sze, Szineszek szi
WHERE	f.FilmID = sze.FilmID
	AND sze.SzineszID = szi.SzineszID	
	AND m.MufajID = f.MufajID
	AND szi.SzineszNev = @pSzineszNev
	AND m.MufajNev = @pMufajNev
)
GO

SELECT * FROM SzineszMufaj('Rozella Willcot', 'Comedy')

--2. Írjunk tárolt eljárást, amelynek bemenő paramétere: @SzineszSzam (int típusú)! A tárolt
--eljárás minden filmnek a költségét növeli 5%-kal, amelyben legalább annyi (>) színész szerepel,
--mint @SzineszSzam!
GO
CREATE PROCEDURE SzineszSzam (@SzineszSzam INT) AS BEGIN

DECLARE cursor1 CURSOR FOR
SELECT	FilmID
FROM	Filmek
OPEN cursor1

DECLARE @filmID INT, @tempSzineszSz INT
FETCH NEXT FROM cursor1 INTO @filmID
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @tempSzineszSz =(	SELECT	COUNT(DISTINCT SzineszID) 
							FROM	Szerepel
							WHERE	FilmID = @filmID )
	IF @tempSzineszSz > @SzineszSzam
		UPDATE Filmek SET Koltseg = Koltseg * 105 / 100 WHERE FilmID = @filmID

	FETCH NEXT FROM cursor1 INTO @filmID
END

CLOSE cursor1
DEALLOCATE cursor1
END
GO

select * from filmek
EXEC SzineszSzam 3
EXEC SzineszSzam 5
select * from filmek

--3. a. Szúrjuk be a Nepszeruseg mezőt a Filmek táblába, ahol a Nepszeruseg-INT típusú mező,
--0-5 közötti értékeket vehet fel, alapértelmezés szerinti értéke 0!
ALTER TABLE Filmek
ADD Nepszeruseg INT DEFAULT 0 WITH VALUES
CHECK (Nepszeruseg BETWEEN 0 AND 5)

--3. b. Írjunk tárolt eljárást, mely minden film esetén beállítja a Nepszeruseg mező értékét
--a film vetítései alapján
GO
CREATE PROCEDURE Jegyadas AS
BEGIN

DECLARE cursor2 CURSOR FOR
SELECT	FilmID
FROM	Filmek
OPEN cursor2

DECLARE @filmID INT, @vetitesSzama INT
FETCH NEXT FROM cursor2 INTO @filmID
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @vetitesSzama =(	SELECT	COUNT(DISTINCT VetitesID) 
							FROM	Vetites
							WHERE	FilmID = @filmID )
	IF @vetitesSzama < 3
		UPDATE Filmek SET Nepszeruseg = 1 WHERE FilmID = @filmID
	ELSE
	BEGIN
		IF @vetitesSzama < 4
			UPDATE Filmek SET Nepszeruseg = 2 WHERE FilmID = @filmID
		ELSE
		BEGIN
			IF @vetitesSzama < 6
				UPDATE Filmek SET Nepszeruseg = 3 WHERE FilmID = @filmID
			ELSE
			BEGIN
				IF @vetitesSzama < 7
					UPDATE Filmek SET Nepszeruseg = 4 WHERE FilmID = @filmID
				ELSE
					UPDATE Filmek SET Nepszeruseg = 5 WHERE FilmID = @filmID
			END
		END
	END

	print @filmID
	FETCH NEXT FROM cursor2 INTO @filmID
END

CLOSE cursor2
DEALLOCATE cursor2
END
GO

exec Jegyadas
SELECT * from filmek

-- 3. c. Írjunk INSERT- illetve DELETE triggert, mely a Vetites táblába való beszúrás, illetve
--törlés esetén aktualizálja a Filmek tábla Nepszeruseg mezőjének értékét! Fontos! NEM elfogadott
--megoldás: ha a triggeren belül egyszerűen csak meghívjuk a b. alpontban megírt tárolt eljárást!

GO
CREATE TRIGGER Beszuraskor ON Filmek AFTER INSERT
AS BEGIN
	DECLARE @beszurtFilmID INT = (SELECT FilmID FROM inserted)
	DECLARE @vetitesSzama INT, @nepsz INT

	SET @vetitesSzama = (SELECT COUNT(DISTINCT VetitesID) FROM Vetites WHERE FilmID = @beszurtFilmID)
	IF @vetitesSzama < 3
		SET @nepsz = 1
	ELSE
	BEGIN
		IF @vetitesSzama < 4
			SET @nepsz = 2
		ELSE
		BEGIN
			IF @vetitesSzama < 6
				SET @nepsz = 3
			ELSE
			BEGIN
				IF @vetitesSzama < 7
					SET @nepsz = 4
				ELSE
					SET @nepsz = 5
			END
		END
	END
	
	UPDATE Filmek SET Nepszeruseg = @nepsz WHERE FilmID = @beszurtFilmID
END
GO


GO
CREATE TRIGGER Torleskor ON Filmek AFTER DELETE
AS BEGIN
	DECLARE @toroltFilmID INT = (SELECT FilmID FROM deleted)
	DECLARE @vetitesSzama INT, @nepsz INT

	SET @vetitesSzama = (SELECT COUNT(DISTINCT VetitesID) FROM Vetites WHERE FilmID = @toroltFilmID)
	IF @vetitesSzama < 3
		SET @nepsz = 1
	ELSE
	BEGIN
		IF @vetitesSzama < 4
			SET @nepsz = 2
		ELSE
		BEGIN
			IF @vetitesSzama < 6
				SET @nepsz = 3
			ELSE
			BEGIN
				IF @vetitesSzama < 7
					SET @nepsz = 4
				ELSE
					SET @nepsz = 5
			END
		END
	END
	
	UPDATE Filmek SET Nepszeruseg = @nepsz WHERE FilmID = @toroltFilmID
END
GO
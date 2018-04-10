-- 1.Írjunk INSERT és UPDATE triggert a Vetites táblára vonatkozóan, amely csak akkor engedélyezi
--a művelet végrehajtását, ha az adott napon vetítendő filmek száma 1 és 10 között marad!-
--Ellenkező esetben írassunk ki megfelelő hibaüzenetet! Megj. Feltételezzük, hogy egyszerre csak
--egy sorát módosítjuk a táblának!
GO
CREATE TRIGGER VetitesDelete ON Vetites INSTEAD OF DELETE AS
BEGIN
	DECLARE @vetSzama int, @vetID int, @vetDatum DATE
	SET @vetID = (SELECT VetitesID FROM deleted)
	SET @vetDatum = (SELECT Datum FROM deleted)
	SET @vetSzama = (SELECT COUNT(DISTINCT VetitesID) FROM Vetites WHERE Datum = @vetDatum)

	IF @vetSzama < 2
	BEGIN
		RAISERROR ('Mar csak egy vetites van!', 1, 1)
	END
	ELSE
	BEGIN
		DELETE FROM Vetites WHERE VetitesID = @vetID
	END
END
GO

GO
CREATE TRIGGER VetitesUpdate ON Vetites INSTEAD OF UPDATE AS
BEGIN
	DECLARE @vetSzama int, @vetID int, @vetDatum DATE
	SET @vetID = (SELECT VetitesID FROM inserted)
	SET @vetDatum = (SELECT Datum FROM inserted)
	SET @vetSzama = (SELECT COUNT(DISTINCT VetitesID) FROM Vetites WHERE Datum = @vetDatum)

	IF @vetSzama >= 10
	BEGIN
		RAISERROR ('Mar van 10 vetites!', 1, 1)
	END
	ELSE
	BEGIN
		UPDATE Vetites SET FilmID = (SELECT FilmID FROM inserted)
		AND Datum = (SELECT Datum FROM inserted)
		WHERE VetitesID = (SELECT VetitesID FROM inserted)
	END
END
GO
-- Irjunk tarolt eljarast amelynek bemeneti parametere egy @pVendegloNev es @pAr.
-- Az adott vendegloben noveljuk 1 lejjel azon italok arat, melyeknek ara kisebb, mint @pAr.

GO
CREATE PROCEDURE ItalDragitas (@pVendegloNev VARCHAR(50), @pAr INT) AS
BEGIN

DECLARE @MenuID INT

SET @MenuID = (
SELECT	DISTINCT m.MenuID
FROM	Vendeglok v, Menuk m, ItalMenu im
WHERE	v.MenuID = m.MenuID
	AND m.MenuID = im.MenuID
	AND v.VendegloNev = @pVendegloNev )

	
	UPDATE	ItalMenu SET Ar = Ar + 1
	WHERE	MenuID = @MenuID
		AND Ar < @pAr
END
GO

select Ar, VendegloNev from vendeglok v, menuk m, italmenu i where v.VendegloID = 1 and v.MenuID = m.MenuID and m.MenuID = i.MenuID
exec ItalDragitas Charlie, 9
select Ar, VendegloNev from vendeglok v, menuk m, italmenu i where v.VendegloID = 1 and v.MenuID = m.MenuID and m.MenuID = i.MenuID

-- Irjunk tarolt eljaras amely bemeneti parametere egy @pNem es @pKor.
-- Irjuk ki azon szemelyek nevet, akik @pNem nemuek es idosebbek @pKor-nal

GO
CREATE PROCEDURE Szem (@pNem VARCHAR(5), @pKor INT) AS
BEGIN

DECLARE cursor2 CURSOR FOR
SELECT	SzemSzam, Nem, SzulDatum
FROM	Szemelyek
OPEN cursor2

DECLARE @SzemSzam VARCHAR(15), @Nem VARCHAR(5), @Szul DATE
FETCH NEXT FROM cursor2 INTO @SzemSzam, @Nem, @Szul
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @Nem = @pNem AND ((YEAR(GETDATE()) - YEAR(@Szul) > @pKor))
		SELECT SzemNev FROM Szemelyek WHERE SzemSzam = @SzemSzam

	FETCH NEXT FROM cursor2 INTO @SzemSzam, @Nem, @Szul
END

CLOSE cursor2
DEALLOCATE cursor2
END
GO

exec Szem 'no', 25
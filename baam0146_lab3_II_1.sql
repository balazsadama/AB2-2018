--1. Írjunk egy INSERT, UPDATE vagy DELETE triggert, mely tartalmaz:
--legalább egyet az alábbiak közül: elágazás, select-ek
--legalább egy adatmódosítást (insert, update agy delete) azon kívül, amelyre kiváltódott a trigger.

go
create trigger ItalTorles on italok instead of delete as
begin

declare kurzor cursor for
select ItalID from deleted
open kurzor

declare @italID int
fetch next from kurzor into @italID

while @@FETCH_STATUS = 0
begin
	delete from ItalMenu where ItalID = @italID
	fetch next from kurzor into @italID
end

delete from Italok where ItalID = @italID

close kurzor
deallocate kurzor
end
go

--2. a. Írjunk egy tárolt eljárást, mely olyan táblákba szúr be adatokat, melyek között m-n típusú
--kapcsolat áll fenn (a kapcsolattáblába is be kell szúrni (legalább) egy sort). Ha valamely
--művelet elvégzésekor hiba lép fel, pörgessük vissza az egész tranzakciót. Az eljárás bemenő
--paraméterei: a táblákba beszúrandó adatok.

go
create procedure BeszurItaltMenubeA (@pMenuID int, @pDarabszam int, @pAr int, @pLeiras varchar(300), @pItalNev varchar(30), @pTerfogat int)
as begin
set nocount on
set transaction isolation level serializable
begin transaction

declare @italID int, @menuID int

set @italID = (select ItalID from Italok where ItalNev = @pItalNev)
if @italID is null
begin
	set @italID = (select max(ItalID) from Italok) + 1
	insert into Italok values (@italID, @pItalNev, @pLeiras, @pTerfogat)

	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end
end

set @menuID = (select MenuID from Menuk where MenuID = @pMenuID)
if @menuID is null
begin
	set @menuID = @pMenuID
	insert into Menuk values (@menuID)

	if @@ERROR <> 0 
	begin
		ROLLBACK TRANSACTION
		return
	end
end

insert into ItalMenu values (@pAr, @MenuID, @italID, @pDarabszam)
if @@ERROR <> 0 
begin
	ROLLBACK TRANSACTION
	return
end

commit
end
go

--2. b.
go
create procedure BeszurItaltMenubeB (@pMenuID int, @pDarabszam int, @pAr int, @pLeiras varchar(300), @pItalNev varchar(30), @pTerfogat int)
as begin
set nocount on
set transaction isolation level serializable
begin transaction

declare @italID int, @menuID int

set @italID = (select ItalID from Italok where ItalNev = @pItalNev)
if @italID is null
begin
	set @italID = (select max(ItalID) from Italok) + 1
	insert into Italok values (@italID, @pItalNev, @pLeiras, @pTerfogat)

	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end
end

save transaction sp1

set @menuID = (select MenuID from Menuk where MenuID = @pMenuID)
if @menuID is null
begin
	set @menuID = @pMenuID
	insert into Menuk values (@menuID)

	if @@ERROR <> 0 
	begin
		ROLLBACK TRANSACTION
		return
	end
end

save transaction sp2

insert into ItalMenu values (@pAr, @MenuID, @italID, @pDarabszam)
if @@ERROR <> 0 
begin
	ROLLBACK TRANSACTION
	return
end

commit
end
go


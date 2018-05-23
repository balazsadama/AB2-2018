--create table Kosarak(
--	KosarID int not null identity(1, 1) primary key,
--	KSzemSzam varchar(15) foreign key references Kliensek(SzemSzam),
--	VendegloID int foreign key references Vendeglok(VendegloID)
--)

--create table KosarTartalma(
--	KosarID int foreign key references Kosarak(KosarID),
--	EtelID int,
--	Mennyiseg int
--)

--create table Szamlafejek(
--	SzamlaSzam int not null identity(1, 1) primary key,
--	KSzemSzam varchar(15) foreign key references Kliensek(SzemSzam),
--	Datum datetime,
--	Vegosszeg int
--)

--create table Szamlasorok(
--	SzamlaSzam int foreign key references Szamlafejek(SzamlaSzam),
--	EtelID int,
--	VendegloID int,
--	Mennyiseg int
--)


--insert into Kosarak (KSzemSzam, VendegloID) values (1670214456279, 2)
--insert into KosarTartalma (KosarID, EtelID, Mennyiseg) values (1, 2, 3)
--insert into KosarTartalma (KosarID, EtelID, Mennyiseg) values (1, 3, 2)



drop procedure Szamlazas
go
create procedure Szamlazas @pszemSzam varchar(15), @pFelhasznalo varchar(50), @pJelszo varchar(50),  @pTelSzam varchar(12), @pDatum date as
begin
set transaction isolation level serializable
begin transaction

declare @kosarID int, @vendegloID int, @menuID int, @szamlaszam int


if (select SzemSzam from Kliensek where SzemSzam = @pszemSzam) is null
begin
	insert into Kliensek (SzemSzam, Felhasznalo, Jelszo, TelSzam) values (@pszemSzam, @pFelhasznalo, @pJelszo, @pTelSzam)
	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end
	commit
	return
end


set @kosarID = (select KosarID from Kosarak where KSzemSzam = @pszemSzam)
if @kosarID is null
begin
	rollback
	return
end

-- @vendegloID szukseges ahhoz, hogy tudjuk, hogy az EtelID altal meghatarozott etel melyik vendeglobol szarmazik
set @vendegloID = (select VendegloID from Kosarak where KosarID = @kosarID)
if @vendegloID is null
begin
	rollback
	return
end


-- @menuID szukseges ahhoz, hogy tudjuk melyik raktarbol kell levonni a rendelt mennyiseget
set @menuID = (select MenuID from Vendeglok where VendegloID = @vendegloID)
if @menuID is null
begin
	rollback
	return
end


insert into Szamlafejek (KSzemSzam, Datum, Vegosszeg) values (@pszemSzam, @pDatum, 0)
if @@ERROR <> 0 
begin
	ROLLBACK
	return
end


-- szukseg van a szamlaszamra amikor noveljuk a vegosszeget
set @szamlaszam = (select SzamlaSzam from Szamlafejek where KSzemSzam = @pszemSzam and Datum = @pDatum and Vegosszeg = 0)


declare @etelID int, @mennyiseg int, @ar int
declare kurzor cursor for (select EtelID, Mennyiseg from KosarTartalma where KosarID = @kosarID)
open kurzor
fetch next from kurzor into @etelID, @mennyiseg
while @@FETCH_STATUS = 0  
begin 

	if @mennyiseg > (select Mennyiseg from EtelMenu where EtelID = @etelID and MenuID = @menuID)
	begin
		rollback
		return
	end

	update EtelMenu set Mennyiseg = Mennyiseg - @mennyiseg where EtelID = @etelID and MenuID = @menuID
	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end

	insert into Szamlasorok (SzamlaSzam, EtelID, VendegloID, Mennyiseg) values (@szamlaszam, @etelID, @vendegloID, @mennyiseg)
	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end	

	set @ar = (select Ar from EtelMenu where EtelID = @etelID and MenuID = @menuID)
	if @ar is null
	begin
		rollback
		return
	end

	update Szamlafejek set Vegosszeg = Vegosszeg + @mennyiseg * @ar where SzamlaSzam = @szamlaSzam
	if @@ERROR <> 0 
	begin
		ROLLBACK
		return
	end	

	fetch next from kurzor into @etelID, @mennyiseg
end

delete from KosarTartalma where KosarID = @kosarID
if @@ERROR <> 0 
begin
	ROLLBACK
	return
end	
delete from Kosarak where KosarID = @kosarID
if @@ERROR <> 0 
begin
	ROLLBACK
	return
end

close kurzor
deallocate kurzor
commit
end
go


declare @datum date
set @datum = getdate()

exec Szamlazas '1670214456279', 'hanna22', 'mittudomen', '0753165795', @datum

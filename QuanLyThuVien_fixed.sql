USE [master];
GO

/* ============================================================
   SCRIPT DB: QuanLyThuVien (BẢN ĐẦY ĐỦ)
   - Tác giả, Thể loại, Sách
   - Độc giả, Phiếu mượn, Chi tiết phiếu mượn
   - Vai trò, Quyền, Tài khoản (đăng nhập)
   - View, Index, Stored Procedure, Trigger
   ============================================================ */

-- Nếu đã có DB thì xóa để tạo lại (bạn có thể comment nếu muốn giữ dữ liệu)
IF DB_ID(N'QuanLyThuVien') IS NOT NULL
BEGIN
    ALTER DATABASE [QuanLyThuVien] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [QuanLyThuVien];
END
GO

CREATE DATABASE [QuanLyThuVien];
GO
USE [QuanLyThuVien];
GO

/* =========================
   0) Thiết lập (tuỳ chọn)
   ========================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =========================
   1) BẢNG DANH MỤC
   ========================= */

-- 1.1 Tác giả
CREATE TABLE dbo.TacGia(
    MaTacGia INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TacGia PRIMARY KEY,
    TenTacGia NVARCHAR(100) NOT NULL,
    NgaySinh   DATE NULL,
    QuocTich   NVARCHAR(50) NULL,
    GhiChu     NVARCHAR(255) NULL,
    NgayTao    DATETIME2(0) NOT NULL CONSTRAINT DF_TacGia_NgayTao DEFAULT (SYSDATETIME()),
    NgayCapNhat DATETIME2(0) NULL
);
GO

CREATE UNIQUE INDEX UX_TacGia_TenTacGia ON dbo.TacGia(TenTacGia);
GO

-- 1.2 Thể loại
CREATE TABLE dbo.TheLoai(
    MaTheLoai INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TheLoai PRIMARY KEY,
    TenTheLoai NVARCHAR(100) NOT NULL,
    MoTa NVARCHAR(255) NULL,
    NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_TheLoai_NgayTao DEFAULT (SYSDATETIME()),
    NgayCapNhat DATETIME2(0) NULL
);
GO

CREATE UNIQUE INDEX UX_TheLoai_TenTheLoai ON dbo.TheLoai(TenTheLoai);
GO

-- 1.3 Sách
CREATE TABLE dbo.Sach(
    MaSach INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sach PRIMARY KEY,
    TenSach NVARCHAR(200) NOT NULL,
    MaTacGia INT NOT NULL,
    MaTheLoai INT NOT NULL,
    NamXuatBan INT NULL,
    NhaXuatBan NVARCHAR(150) NULL,
    ISBN NVARCHAR(20) NULL,
    SoLuong INT NOT NULL CONSTRAINT DF_Sach_SoLuong DEFAULT(0),
    ViTri NVARCHAR(50) NULL,
    GiaNhap DECIMAL(18,2) NULL,
    TrangThai BIT NOT NULL CONSTRAINT DF_Sach_TrangThai DEFAULT(1), -- 1: đang dùng, 0: ngưng
    NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_Sach_NgayTao DEFAULT (SYSDATETIME()),
    NgayCapNhat DATETIME2(0) NULL,
    CONSTRAINT CK_Sach_SoLuong CHECK (SoLuong >= 0)
);
GO

ALTER TABLE dbo.Sach WITH CHECK
ADD CONSTRAINT FK_Sach_TacGia FOREIGN KEY(MaTacGia) REFERENCES dbo.TacGia(MaTacGia);
GO

ALTER TABLE dbo.Sach WITH CHECK
ADD CONSTRAINT FK_Sach_TheLoai FOREIGN KEY(MaTheLoai) REFERENCES dbo.TheLoai(MaTheLoai);
GO

-- Unique “logic” để hỗ trợ ExistsBook(tenSach, maTacGia, maTheLoai)
CREATE UNIQUE INDEX UX_Sach_TenTacGiaTheLoai ON dbo.Sach(TenSach, MaTacGia, MaTheLoai);
GO

-- ISBN nếu có thì không trùng (lọc NULL)
CREATE UNIQUE INDEX UX_Sach_ISBN_NotNull ON dbo.Sach(ISBN) WHERE ISBN IS NOT NULL;
GO

CREATE INDEX IX_Sach_MaTacGia ON dbo.Sach(MaTacGia);
CREATE INDEX IX_Sach_MaTheLoai ON dbo.Sach(MaTheLoai);
GO

/* =========================
   2) ĐỘC GIẢ + MƯỢN/TRẢ
   ========================= */

-- 2.1 Độc giả
CREATE TABLE dbo.DocGia(
    MaDocGia INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocGia PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    NgaySinh DATE NULL,
    GioiTinh NVARCHAR(10) NULL,
    SDT VARCHAR(15) NULL,
    Email VARCHAR(100) NULL,
    DiaChi NVARCHAR(200) NULL,
    NgayDangKy DATE NOT NULL CONSTRAINT DF_DocGia_NgayDangKy DEFAULT (CONVERT(date, GETDATE())),
    TrangThai BIT NOT NULL CONSTRAINT DF_DocGia_TrangThai DEFAULT(1),
    GhiChu NVARCHAR(255) NULL
);
GO

CREATE INDEX IX_DocGia_HoTen ON dbo.DocGia(HoTen);
CREATE INDEX IX_DocGia_SDT ON dbo.DocGia(SDT);
GO

-- 2.2 Phiếu mượn
CREATE TABLE dbo.PhieuMuon(
    MaPhieu INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PhieuMuon PRIMARY KEY,
    MaDocGia INT NOT NULL,
    NgayMuon DATE NOT NULL CONSTRAINT DF_PhieuMuon_NgayMuon DEFAULT (CONVERT(date, GETDATE())),
    HanTra  DATE NOT NULL,
    NgayTra DATE NULL,
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_PhieuMuon_TrangThai DEFAULT(N'Đang mượn'), -- Đang mượn | Đã trả | Quá hạn | Hủy
    GhiChu NVARCHAR(255) NULL
);
GO

ALTER TABLE dbo.PhieuMuon WITH CHECK
ADD CONSTRAINT FK_PhieuMuon_DocGia FOREIGN KEY(MaDocGia) REFERENCES dbo.DocGia(MaDocGia);
GO

CREATE INDEX IX_PhieuMuon_MaDocGia ON dbo.PhieuMuon(MaDocGia);
CREATE INDEX IX_PhieuMuon_TrangThai ON dbo.PhieuMuon(TrangThai);
GO

-- 2.3 Chi tiết phiếu mượn
CREATE TABLE dbo.CT_PhieuMuon(
    MaPhieu INT NOT NULL,
    MaSach INT NOT NULL,
    SoLuong INT NOT NULL CONSTRAINT DF_CTPhieuMuon_SoLuong DEFAULT(1),
    GhiChu NVARCHAR(255) NULL,
    CONSTRAINT PK_CT_PhieuMuon PRIMARY KEY CLUSTERED (MaPhieu, MaSach),
    CONSTRAINT CK_CTPhieuMuon_SoLuong CHECK (SoLuong > 0)
);
GO

ALTER TABLE dbo.CT_PhieuMuon WITH CHECK
ADD CONSTRAINT FK_CTPhieuMuon_PhieuMuon FOREIGN KEY(MaPhieu) REFERENCES dbo.PhieuMuon(MaPhieu) ON DELETE CASCADE;
GO

ALTER TABLE dbo.CT_PhieuMuon WITH CHECK
ADD CONSTRAINT FK_CTPhieuMuon_Sach FOREIGN KEY(MaSach) REFERENCES dbo.Sach(MaSach);
GO

CREATE INDEX IX_CTPhieuMuon_MaSach ON dbo.CT_PhieuMuon(MaSach);
GO

/* =========================
   3) PHÂN QUYỀN / TÀI KHOẢN
   ========================= */

CREATE TABLE dbo.VaiTro(
    MaVaiTro INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VaiTro PRIMARY KEY,
    TenVaiTro NVARCHAR(50) NOT NULL,
    MoTa NVARCHAR(255) NULL
);
GO
CREATE UNIQUE INDEX UX_VaiTro_TenVaiTro ON dbo.VaiTro(TenVaiTro);
GO

CREATE TABLE dbo.Quyen(
    MaQuyen INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Quyen PRIMARY KEY,
    TenQuyen NVARCHAR(50) NOT NULL,
    MoTa NVARCHAR(255) NULL
);
GO
CREATE UNIQUE INDEX UX_Quyen_TenQuyen ON dbo.Quyen(TenQuyen);
GO

CREATE TABLE dbo.VaiTro_Quyen(
    MaVaiTro INT NOT NULL,
    MaQuyen INT NOT NULL,
    CONSTRAINT PK_VaiTro_Quyen PRIMARY KEY CLUSTERED (MaVaiTro, MaQuyen)
);
GO

ALTER TABLE dbo.VaiTro_Quyen WITH CHECK
ADD CONSTRAINT FK_VTQ_VaiTro FOREIGN KEY(MaVaiTro) REFERENCES dbo.VaiTro(MaVaiTro) ON DELETE CASCADE;
GO

ALTER TABLE dbo.VaiTro_Quyen WITH CHECK
ADD CONSTRAINT FK_VTQ_Quyen FOREIGN KEY(MaQuyen) REFERENCES dbo.Quyen(MaQuyen) ON DELETE CASCADE;
GO

CREATE TABLE dbo.TaiKhoan(
    TenDangNhap VARCHAR(50) NOT NULL CONSTRAINT PK_TaiKhoan PRIMARY KEY,
    MatKhauHash VARCHAR(255) NULL,
    MatKhauSalt VARCHAR(255) NULL,
    MaVaiTro INT NULL,
    MaDocGia INT NULL,
    TrangThai BIT NOT NULL CONSTRAINT DF_TaiKhoan_TrangThai DEFAULT(1),
    LanDangNhapCuoi DATETIME2(0) NULL,
    NgayTao DATETIME2(0) NOT NULL CONSTRAINT DF_TaiKhoan_NgayTao DEFAULT(SYSDATETIME())
);
GO

ALTER TABLE dbo.TaiKhoan WITH CHECK
ADD CONSTRAINT FK_TaiKhoan_VaiTro FOREIGN KEY(MaVaiTro) REFERENCES dbo.VaiTro(MaVaiTro);
GO

ALTER TABLE dbo.TaiKhoan WITH CHECK
ADD CONSTRAINT FK_TaiKhoan_DocGia FOREIGN KEY(MaDocGia) REFERENCES dbo.DocGia(MaDocGia);
GO

CREATE INDEX IX_TaiKhoan_MaVaiTro ON dbo.TaiKhoan(MaVaiTro);
CREATE INDEX IX_TaiKhoan_MaDocGia ON dbo.TaiKhoan(MaDocGia);
GO

/* =========================
   4) VIEW
   ========================= */

CREATE OR ALTER VIEW dbo.vw_Sach_ChiTiet
AS
SELECT
    s.MaSach,
    s.TenSach,
    s.MaTacGia,
    tg.TenTacGia,
    s.MaTheLoai,
    tl.TenTheLoai,
    s.NamXuatBan,
    s.NhaXuatBan,
    s.ISBN,
    s.SoLuong,
    s.ViTri,
    s.GiaNhap,
    s.TrangThai,
    s.NgayTao,
    s.NgayCapNhat
FROM dbo.Sach s
JOIN dbo.TacGia tg ON tg.MaTacGia = s.MaTacGia
JOIN dbo.TheLoai tl ON tl.MaTheLoai = s.MaTheLoai;
GO

CREATE OR ALTER VIEW dbo.vw_PhieuMuon_ChiTiet
AS
SELECT
    pm.MaPhieu,
    pm.MaDocGia,
    dg.HoTen,
    pm.NgayMuon,
    pm.HanTra,
    pm.NgayTra,
    pm.TrangThai,
    ct.MaSach,
    s.TenSach,
    ct.SoLuong,
    ct.GhiChu
FROM dbo.PhieuMuon pm
JOIN dbo.DocGia dg ON dg.MaDocGia = pm.MaDocGia
JOIN dbo.CT_PhieuMuon ct ON ct.MaPhieu = pm.MaPhieu
JOIN dbo.Sach s ON s.MaSach = ct.MaSach;
GO

/* =========================
   5) TABLE TYPE
   ========================= */

CREATE TYPE dbo.TT_CTPhieuMuon AS TABLE(
    MaSach INT NOT NULL,
    SoLuong INT NOT NULL
);
GO

/* =========================
   6) TRIGGER
   ========================= */

CREATE OR ALTER TRIGGER dbo.TR_CTPhieuMuon_TruSoLuong
ON dbo.CT_PhieuMuon
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS(
        SELECT 1
        FROM inserted i
        JOIN dbo.Sach s ON s.MaSach = i.MaSach
        WHERE s.SoLuong < i.SoLuong
    )
    BEGIN
        RAISERROR(N'Số lượng sách trong kho không đủ.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE s
    SET s.SoLuong = s.SoLuong - i.SoLuong,
        s.NgayCapNhat = SYSDATETIME()
    FROM dbo.Sach s
    JOIN inserted i ON i.MaSach = s.MaSach;
END
GO

CREATE OR ALTER TRIGGER dbo.TR_CTPhieuMuon_HoanSoLuong
ON dbo.CT_PhieuMuon
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE s
    SET s.SoLuong = s.SoLuong + d.SoLuong,
        s.NgayCapNhat = SYSDATETIME()
    FROM dbo.Sach s
    JOIN deleted d ON d.MaSach = s.MaSach;
END
GO

/* =========================
   7) STORED PROCEDURE - TACGIA
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_TacGia_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.TacGia ORDER BY TenTacGia;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TacGia_Add
    @TenTacGia NVARCHAR(100),
    @NgaySinh DATE = NULL,
    @QuocTich NVARCHAR(50) = NULL,
    @GhiChu NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.TacGia WHERE TenTacGia = @TenTacGia)
    BEGIN
        RAISERROR(N'Tác giả đã tồn tại.', 16, 1);
        RETURN;
    END

    INSERT dbo.TacGia(TenTacGia, NgaySinh, QuocTich, GhiChu)
    VALUES(@TenTacGia, @NgaySinh, @QuocTich, @GhiChu);

    SELECT SCOPE_IDENTITY() AS MaTacGia;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TacGia_Update
    @MaTacGia INT,
    @TenTacGia NVARCHAR(100),
    @NgaySinh DATE = NULL,
    @QuocTich NVARCHAR(50) = NULL,
    @GhiChu NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.TacGia WHERE MaTacGia = @MaTacGia)
    BEGIN
        RAISERROR(N'Không tìm thấy tác giả.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.TacGia WHERE TenTacGia = @TenTacGia AND MaTacGia <> @MaTacGia)
    BEGIN
        RAISERROR(N'Tên tác giả bị trùng.', 16, 1);
        RETURN;
    END

    UPDATE dbo.TacGia
    SET TenTacGia = @TenTacGia,
        NgaySinh = @NgaySinh,
        QuocTich = @QuocTich,
        GhiChu = @GhiChu,
        NgayCapNhat = SYSDATETIME()
    WHERE MaTacGia = @MaTacGia;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TacGia_Delete
    @MaTacGia INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Sach WHERE MaTacGia = @MaTacGia)
    BEGIN
        RAISERROR(N'Không thể xoá tác giả vì đang có sách tham chiếu.', 16, 1);
        RETURN;
    END

    DELETE dbo.TacGia WHERE MaTacGia = @MaTacGia;
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

/* =========================
   8) STORED PROCEDURE - THELOAI
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_TheLoai_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.TheLoai ORDER BY TenTheLoai;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TheLoai_Add
    @TenTheLoai NVARCHAR(100),
    @MoTa NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.TheLoai WHERE TenTheLoai = @TenTheLoai)
    BEGIN
        RAISERROR(N'Thể loại đã tồn tại.', 16, 1);
        RETURN;
    END

    INSERT dbo.TheLoai(TenTheLoai, MoTa)
    VALUES(@TenTheLoai, @MoTa);

    SELECT SCOPE_IDENTITY() AS MaTheLoai;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TheLoai_Update
    @MaTheLoai INT,
    @TenTheLoai NVARCHAR(100),
    @MoTa NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.TheLoai WHERE MaTheLoai = @MaTheLoai)
    BEGIN
        RAISERROR(N'Không tìm thấy thể loại.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.TheLoai WHERE TenTheLoai = @TenTheLoai AND MaTheLoai <> @MaTheLoai)
    BEGIN
        RAISERROR(N'Tên thể loại bị trùng.', 16, 1);
        RETURN;
    END

    UPDATE dbo.TheLoai
    SET TenTheLoai = @TenTheLoai,
        MoTa = @MoTa,
        NgayCapNhat = SYSDATETIME()
    WHERE MaTheLoai = @MaTheLoai;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TheLoai_Delete
    @MaTheLoai INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Sach WHERE MaTheLoai = @MaTheLoai)
    BEGIN
        RAISERROR(N'Không thể xoá thể loại vì đang có sách tham chiếu.', 16, 1);
        RETURN;
    END

    DELETE dbo.TheLoai WHERE MaTheLoai = @MaTheLoai;
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

/* =========================
   9) STORED PROCEDURE - SACH
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_Sach_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_Sach_ChiTiet ORDER BY TenSach;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sach_Exists
    @TenSach NVARCHAR(200),
    @MaTacGia INT,
    @MaTheLoai INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CASE WHEN EXISTS(
        SELECT 1 FROM dbo.Sach
        WHERE TenSach = @TenSach AND MaTacGia = @MaTacGia AND MaTheLoai = @MaTheLoai
    ) THEN 1 ELSE 0 END AS IsExists;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sach_Add
    @TenSach NVARCHAR(200),
    @MaTacGia INT,
    @MaTheLoai INT,
    @NamXuatBan INT = NULL,
    @NhaXuatBan NVARCHAR(150) = NULL,
    @ISBN NVARCHAR(20) = NULL,
    @SoLuong INT = 0,
    @ViTri NVARCHAR(50) = NULL,
    @GiaNhap DECIMAL(18,2) = NULL,
    @TrangThai BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Sach WHERE TenSach=@TenSach AND MaTacGia=@MaTacGia AND MaTheLoai=@MaTheLoai)
    BEGIN
        RAISERROR(N'Sách đã tồn tại (trùng Tên + Tác giả + Thể loại).', 16, 1);
        RETURN;
    END

    INSERT dbo.Sach(TenSach, MaTacGia, MaTheLoai, NamXuatBan, NhaXuatBan, ISBN, SoLuong, ViTri, GiaNhap, TrangThai)
    VALUES(@TenSach, @MaTacGia, @MaTheLoai, @NamXuatBan, @NhaXuatBan, @ISBN, @SoLuong, @ViTri, @GiaNhap, @TrangThai);

    SELECT SCOPE_IDENTITY() AS MaSach;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sach_Update
    @MaSach INT,
    @TenSach NVARCHAR(200),
    @MaTacGia INT,
    @MaTheLoai INT,
    @NamXuatBan INT = NULL,
    @NhaXuatBan NVARCHAR(150) = NULL,
    @ISBN NVARCHAR(20) = NULL,
    @SoLuong INT = 0,
    @ViTri NVARCHAR(50) = NULL,
    @GiaNhap DECIMAL(18,2) = NULL,
    @TrangThai BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Sach WHERE MaSach=@MaSach)
    BEGIN
        RAISERROR(N'Không tìm thấy sách.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Sach WHERE TenSach=@TenSach AND MaTacGia=@MaTacGia AND MaTheLoai=@MaTheLoai AND MaSach<>@MaSach)
    BEGIN
        RAISERROR(N'Sách bị trùng (Tên + Tác giả + Thể loại).', 16, 1);
        RETURN;
    END

    UPDATE dbo.Sach
    SET TenSach=@TenSach,
        MaTacGia=@MaTacGia,
        MaTheLoai=@MaTheLoai,
        NamXuatBan=@NamXuatBan,
        NhaXuatBan=@NhaXuatBan,
        ISBN=@ISBN,
        SoLuong=@SoLuong,
        ViTri=@ViTri,
        GiaNhap=@GiaNhap,
        TrangThai=@TrangThai,
        NgayCapNhat=SYSDATETIME()
    WHERE MaSach=@MaSach;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sach_Delete
    @MaSach INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.CT_PhieuMuon WHERE MaSach=@MaSach)
    BEGIN
        RAISERROR(N'Không thể xoá sách vì đã phát sinh phiếu mượn.', 16, 1);
        RETURN;
    END

    DELETE dbo.Sach WHERE MaSach=@MaSach;
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sach_Search
    @Keyword NVARCHAR(200) = NULL,
    @MaTacGia INT = NULL,
    @MaTheLoai INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Sach_ChiTiet
    WHERE
        (@Keyword IS NULL OR TenSach LIKE N'%' + @Keyword + N'%' OR TenTacGia LIKE N'%' + @Keyword + N'%' OR TenTheLoai LIKE N'%' + @Keyword + N'%')
        AND (@MaTacGia IS NULL OR MaTacGia = @MaTacGia)
        AND (@MaTheLoai IS NULL OR MaTheLoai = @MaTheLoai)
    ORDER BY TenSach;
END
GO

/* =========================
   10) STORED PROCEDURE - DOCGIA
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_DocGia_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.DocGia ORDER BY HoTen;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocGia_Add
    @HoTen NVARCHAR(100),
    @NgaySinh DATE = NULL,
    @GioiTinh NVARCHAR(10) = NULL,
    @SDT VARCHAR(15) = NULL,
    @Email VARCHAR(100) = NULL,
    @DiaChi NVARCHAR(200) = NULL,
    @TrangThai BIT = 1,
    @GhiChu NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.DocGia(HoTen, NgaySinh, GioiTinh, SDT, Email, DiaChi, TrangThai, GhiChu)
    VALUES(@HoTen, @NgaySinh, @GioiTinh, @SDT, @Email, @DiaChi, @TrangThai, @GhiChu);

    SELECT SCOPE_IDENTITY() AS MaDocGia;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocGia_Update
    @MaDocGia INT,
    @HoTen NVARCHAR(100),
    @NgaySinh DATE = NULL,
    @GioiTinh NVARCHAR(10) = NULL,
    @SDT VARCHAR(15) = NULL,
    @Email VARCHAR(100) = NULL,
    @DiaChi NVARCHAR(200) = NULL,
    @TrangThai BIT = 1,
    @GhiChu NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.DocGia WHERE MaDocGia=@MaDocGia)
    BEGIN
        RAISERROR(N'Không tìm thấy độc giả.', 16, 1);
        RETURN;
    END

    UPDATE dbo.DocGia
    SET HoTen=@HoTen,
        NgaySinh=@NgaySinh,
        GioiTinh=@GioiTinh,
        SDT=@SDT,
        Email=@Email,
        DiaChi=@DiaChi,
        TrangThai=@TrangThai,
        GhiChu=@GhiChu
    WHERE MaDocGia=@MaDocGia;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocGia_Delete
    @MaDocGia INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.PhieuMuon WHERE MaDocGia=@MaDocGia)
    BEGIN
        RAISERROR(N'Không thể xoá độc giả vì đã phát sinh phiếu mượn.', 16, 1);
        RETURN;
    END

    DELETE dbo.DocGia WHERE MaDocGia=@MaDocGia;
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DocGia_Search
    @Keyword NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.DocGia
    WHERE (@Keyword IS NULL OR HoTen LIKE N'%' + @Keyword + N'%' OR SDT LIKE '%' + @Keyword + '%' OR Email LIKE '%' + @Keyword + '%')
    ORDER BY HoTen;
END
GO

/* =========================
   11) STORED PROCEDURE - PHIEUMUON
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_Create
    @MaDocGia INT,
    @HanTra DATE,
    @ChiTiet dbo.TT_CTPhieuMuon READONLY,
    @GhiChu NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM dbo.DocGia WHERE MaDocGia=@MaDocGia AND TrangThai=1)
    BEGIN
        RAISERROR(N'Độc giả không tồn tại hoặc đang bị khoá.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    INSERT dbo.PhieuMuon(MaDocGia, HanTra, TrangThai, GhiChu)
    VALUES(@MaDocGia, @HanTra, N'Đang mượn', @GhiChu);

    DECLARE @MaPhieu INT = SCOPE_IDENTITY();

    INSERT dbo.CT_PhieuMuon(MaPhieu, MaSach, SoLuong)
    SELECT @MaPhieu, MaSach, SoLuong
    FROM @ChiTiet;

    COMMIT;

    SELECT @MaPhieu AS MaPhieu;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_Return
    @MaPhieu INT,
    @NgayTra DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @NgayTra IS NULL SET @NgayTra = CONVERT(date, GETDATE());

    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM dbo.PhieuMuon WHERE MaPhieu=@MaPhieu)
    BEGIN
        RAISERROR(N'Không tìm thấy phiếu mượn.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.PhieuMuon WHERE MaPhieu=@MaPhieu AND TrangThai IN (N'Đã trả', N'Hủy'))
    BEGIN
        RAISERROR(N'Phiếu đã trả hoặc đã hủy.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    UPDATE s
    SET s.SoLuong = s.SoLuong + ct.SoLuong,
        s.NgayCapNhat = SYSDATETIME()
    FROM dbo.Sach s
    JOIN dbo.CT_PhieuMuon ct ON ct.MaSach = s.MaSach
    WHERE ct.MaPhieu = @MaPhieu;

    UPDATE dbo.PhieuMuon
    SET NgayTra = @NgayTra,
        TrangThai = N'Đã trả'
    WHERE MaPhieu = @MaPhieu;

    COMMIT;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_Cancel
    @MaPhieu INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM dbo.PhieuMuon WHERE MaPhieu=@MaPhieu)
    BEGIN
        RAISERROR(N'Không tìm thấy phiếu mượn.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.PhieuMuon WHERE MaPhieu=@MaPhieu AND TrangThai=N'Đã trả')
    BEGIN
        RAISERROR(N'Phiếu đã trả, không thể hủy.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    DELETE dbo.PhieuMuon WHERE MaPhieu=@MaPhieu;

    COMMIT;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_GetByDocGia
    @MaDocGia INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.PhieuMuon
    WHERE MaDocGia=@MaDocGia
    ORDER BY MaPhieu DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_GetDetails
    @MaPhieu INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.vw_PhieuMuon_ChiTiet
    WHERE MaPhieu=@MaPhieu
    ORDER BY TenSach;
END
GO

/* =========================
   12) STORED PROCEDURE - AUTH
   ========================= */

CREATE OR ALTER PROCEDURE dbo.sp_Auth_GetRoleAndPermissions
    @TenDangNhap VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tk.TenDangNhap,
        tk.MaVaiTro,
        vt.TenVaiTro
    FROM dbo.TaiKhoan tk
    LEFT JOIN dbo.VaiTro vt ON vt.MaVaiTro = tk.MaVaiTro
    WHERE tk.TenDangNhap = @TenDangNhap;

    SELECT q.TenQuyen
    FROM dbo.TaiKhoan tk
    JOIN dbo.VaiTro_Quyen vtq ON vtq.MaVaiTro = tk.MaVaiTro
    JOIN dbo.Quyen q ON q.MaQuyen = vtq.MaQuyen
    WHERE tk.TenDangNhap = @TenDangNhap
    ORDER BY q.TenQuyen;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Auth_Login
    @TenDangNhap VARCHAR(50),
    @MatKhau VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS(
        SELECT 1 FROM dbo.TaiKhoan
        WHERE TenDangNhap=@TenDangNhap
          AND TrangThai=1
          AND MatKhauHash=@MatKhau
    )
    BEGIN
        UPDATE dbo.TaiKhoan
        SET LanDangNhapCuoi = SYSDATETIME()
        WHERE TenDangNhap=@TenDangNhap;

        SELECT 1 AS IsOk;
        RETURN;
    END

    SELECT 0 AS IsOk;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TaiKhoan_Add
    @TenDangNhap VARCHAR(50),
    @MatKhau VARCHAR(255),
    @MaVaiTro INT = NULL,
    @MaDocGia INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.TaiKhoan WHERE TenDangNhap=@TenDangNhap)
    BEGIN
        RAISERROR(N'Tên đăng nhập đã tồn tại.', 16, 1);
        RETURN;
    END

    INSERT dbo.TaiKhoan(TenDangNhap, MatKhauHash, MaVaiTro, MaDocGia)
    VALUES(@TenDangNhap, @MatKhau, @MaVaiTro, @MaDocGia);

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_TaiKhoan_SetStatus
    @TenDangNhap VARCHAR(50),
    @TrangThai BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.TaiKhoan
    SET TrangThai=@TrangThai
    WHERE TenDangNhap=@TenDangNhap;

    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

/* =========================
   13) DỮ LIỆU MẪU (SEED)
   ========================= */

INSERT dbo.TacGia(TenTacGia, NgaySinh, QuocTich) VALUES
(N'Nguyễn Nhật Ánh','1955-05-07',N'Việt Nam'),
(N'Haruki Murakami','1949-01-12',N'Nhật Bản'),
(N'J.K. Rowling','1965-07-31',N'Anh'),
(N'Yuval Noah Harari','1976-02-24',N'Israel'),
(N'Paulo Coelho','1947-08-24',N'Brazil');
GO

INSERT dbo.TheLoai(TenTheLoai, MoTa) VALUES
(N'Thiếu nhi', N'Sách cho thiếu nhi'),
(N'Tiểu thuyết', N'Tiểu thuyết trong/ngoài nước'),
(N'Kỹ năng', N'Phát triển bản thân'),
(N'Giáo trình', N'Tài liệu học tập'),
(N'Lịch sử', N'Lịch sử - xã hội');
GO

INSERT dbo.Sach(TenSach, MaTacGia, MaTheLoai, NamXuatBan, NhaXuatBan, ISBN, SoLuong, ViTri, GiaNhap, TrangThai) VALUES
(N'Cho tôi xin một vé đi tuổi thơ', 1, 1, 2008, N'NXB Trẻ', NULL, 10, N'Kệ A1', 45000, 1),
(N'Rừng Na Uy', 2, 2, 1987, N'Kodansha', NULL, 5, N'Kệ B2', 120000, 1),
(N'Harry Potter và Hòn đá Phù thủy', 3, 2, 1997, N'Bloomsbury', NULL, 7, N'Kệ B1', 150000, 1),
(N'Sapiens: Lược sử loài người', 4, 5, 2011, N'Harvill Secker', NULL, 8, N'Kệ C3', 220000, 1),
(N'Nhà giả kim', 5, 2, 1988, N'HarperCollins', NULL, 12, N'Kệ B3', 90000, 1);
GO

INSERT dbo.DocGia(HoTen, NgaySinh, GioiTinh, SDT, Email, DiaChi, TrangThai) VALUES
(N'Lê Đức Anh','2003-09-10',N'Nam','0900000001','ducanh@example.com',N'Hà Nội',1),
(N'Nguyễn Thị B','2004-03-22',N'Nữ','0900000002','b@example.com',N'Đà Nẵng',1),
(N'Trần Văn C','2002-11-05',N'Nam','0900000003','c@example.com',N'HCM',1);
GO

INSERT dbo.VaiTro(TenVaiTro, MoTa) VALUES
(N'Admin',N'Quản trị hệ thống'),
(N'Thủ thư',N'Quản lý sách và mượn/trả'),
(N'Độc giả',N'Tài khoản độc giả');
GO

INSERT dbo.Quyen(TenQuyen, MoTa) VALUES
(N'QuanLySach', N'Thêm/sửa/xóa sách'),
(N'QuanLyTacGia', N'Thêm/sửa/xóa tác giả'),
(N'QuanLyTheLoai', N'Thêm/sửa/xóa thể loại'),
(N'QuanLyDocGia', N'Thêm/sửa/xóa độc giả'),
(N'MuonTra', N'Tạo phiếu mượn/trả'),
(N'QuanTri', N'Quản trị tài khoản/quyền');
GO

INSERT dbo.VaiTro_Quyen(MaVaiTro, MaQuyen)
SELECT 1, MaQuyen FROM dbo.Quyen;
GO

INSERT dbo.VaiTro_Quyen(MaVaiTro, MaQuyen) VALUES
(2,1),(2,2),(2,3),(2,4),(2,5);
GO

INSERT dbo.VaiTro_Quyen(MaVaiTro, MaQuyen) VALUES
(3,5);
GO

INSERT dbo.TaiKhoan(TenDangNhap, MatKhauHash, MaVaiTro, MaDocGia) VALUES
('admin','1234',1,NULL),
('thuthu','1234',2,NULL),
('dg01','1234',3,1);
GO

PRINT N'✅ Đã tạo xong DB QuanLyThuVien (đầy đủ bảng, view, proc, trigger, seed data).';
GO

/* ============================================================
   PATCH FIX - tối ưu cho Python + CustomTkinter + pyodbc
   ============================================================ */

-- 1) Bổ sung ràng buộc hạn trả không nhỏ hơn ngày mượn
IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_PhieuMuon_HanTra'
      AND parent_object_id = OBJECT_ID(N'dbo.PhieuMuon')
)
BEGIN
    ALTER TABLE dbo.PhieuMuon
    ADD CONSTRAINT CK_PhieuMuon_HanTra CHECK (HanTra >= NgayMuon);
END
GO

-- 2) Đồng bộ trạng thái quá hạn để dashboard và màn hình trả sách hiển thị đúng
CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_SyncOverdueStatus
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.PhieuMuon
    SET TrangThai = N'Quá hạn'
    WHERE NgayTra IS NULL
      AND HanTra < CONVERT(date, GETDATE())
      AND TrangThai = N'Đang mượn';

    UPDATE dbo.PhieuMuon
    SET TrangThai = N'Đang mượn'
    WHERE NgayTra IS NULL
      AND HanTra >= CONVERT(date, GETDATE())
      AND TrangThai = N'Quá hạn';
END
GO

-- 3) View tổng hợp phiếu mượn để Python gọi dễ, không cần tự group nhiều lần
CREATE OR ALTER VIEW dbo.vw_PhieuMuon_TongHop
AS
SELECT
    pm.MaPhieu,
    pm.MaDocGia,
    dg.HoTen,
    pm.NgayMuon,
    pm.HanTra,
    pm.NgayTra,
    pm.TrangThai,
    CASE
        WHEN pm.NgayTra IS NULL AND pm.HanTra < CONVERT(date, GETDATE()) THEN N'Quá hạn'
        WHEN pm.NgayTra IS NOT NULL THEN N'Đã trả'
        ELSE pm.TrangThai
    END AS TrangThaiHienThi,
    COUNT(ct.MaSach) AS SoLoaiSach,
    ISNULL(SUM(ct.SoLuong), 0) AS TongSoLuong
FROM dbo.PhieuMuon pm
JOIN dbo.DocGia dg ON dg.MaDocGia = pm.MaDocGia
LEFT JOIN dbo.CT_PhieuMuon ct ON ct.MaPhieu = pm.MaPhieu
GROUP BY pm.MaPhieu, pm.MaDocGia, dg.HoTen, pm.NgayMuon, pm.HanTra, pm.NgayTra, pm.TrangThai;
GO

-- 4) Proc danh sách phiếu mượn tổng hợp
CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_ListAll
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_PhieuMuon_SyncOverdueStatus;

    SELECT *
    FROM dbo.vw_PhieuMuon_TongHop
    ORDER BY MaPhieu DESC;
END
GO

-- 5) Dashboard stats cho app Python gọi một lần là đủ dữ liệu
CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_Stats
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_PhieuMuon_SyncOverdueStatus;

    SELECT
        (SELECT COUNT(*) FROM dbo.Sach) AS TongDauSach,
        (SELECT ISNULL(SUM(SoLuong), 0) FROM dbo.Sach) AS TongSoLuongSach,
        (SELECT COUNT(*) FROM dbo.DocGia WHERE TrangThai = 1) AS TongDocGia,
        (SELECT COUNT(*) FROM dbo.PhieuMuon WHERE TrangThai = N'Đang mượn') AS PhieuDangMuon,
        (SELECT COUNT(*) FROM dbo.PhieuMuon WHERE TrangThai = N'Quá hạn') AS PhieuQuaHan,
        (SELECT COUNT(*) FROM dbo.PhieuMuon WHERE TrangThai = N'Đã trả') AS PhieuDaTra;
END
GO

-- 6) Proc tìm kiếm phiếu mượn (nếu cần mở rộng sau này)
CREATE OR ALTER PROCEDURE dbo.sp_PhieuMuon_Search
    @Keyword NVARCHAR(100) = NULL,
    @TrangThai NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_PhieuMuon_SyncOverdueStatus;

    SELECT *
    FROM dbo.vw_PhieuMuon_TongHop
    WHERE
        (@Keyword IS NULL OR CAST(MaPhieu AS NVARCHAR(20)) LIKE N'%' + @Keyword + N'%' OR HoTen LIKE N'%' + @Keyword + N'%')
        AND (@TrangThai IS NULL OR TrangThaiHienThi = @TrangThai)
    ORDER BY MaPhieu DESC;
END
GO

PRINT N'✅ Đã áp dụng patch tối ưu cho app Python/CustomTkinter.';
GO

-- Create Members table
CREATE TABLE Member (
    Member_ID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL CHECK (Email LIKE '%@%.%'),
    Phone VARCHAR(20),
    Address VARCHAR(MAX),
    MembershipDate DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CHK_ValidEmail CHECK (Email LIKE '%_@__%.__%')
);

-- Create Staff table
CREATE TABLE Staff (
    Staff_ID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL CHECK (Email LIKE '%@%.%')
);

-- Simplified Books table
CREATE TABLE ADD_BOOKS (
    Book_ID INT IDENTITY(1,1) PRIMARY KEY,
    ISBN VARCHAR(50) UNIQUE,
    Title VARCHAR(255) NOT NULL,
    Author_name VARCHAR(100) NOT NULL,
    BOOK_Status VARCHAR(20) NOT NULL DEFAULT 'Available' 
    CHECK (BOOK_Status IN ('Available', 'Checked Out')),
    TotalCopies INT NOT NULL DEFAULT 1 CHECK (TotalCopies >= 0),
    AvailableCopies INT NOT NULL DEFAULT 1 CHECK (AvailableCopies >= 0),
    CONSTRAINT CHK_Copies CHECK (AvailableCopies <= TotalCopies AND AvailableCopies >= 0)
);

-- Create BorrowedBooks table
CREATE TABLE BorrowedBooks (
    Borrow_ID INT IDENTITY(1,1) PRIMARY KEY,
    Member_ID INT NOT NULL,
    Book_ID INT NOT NULL,
    IssueDate DATE NOT NULL DEFAULT GETDATE(),
    DueDate DATE NOT NULL DEFAULT DATEADD(DAY, 14, GETDATE()),
    Staff_ID INT NOT NULL,
    IsReturned BIT DEFAULT 0,
    CONSTRAINT FK_BorrowedBooks_Member FOREIGN KEY (Member_ID) REFERENCES Member(Member_ID),
    CONSTRAINT FK_BorrowedBooks_Book FOREIGN KEY (Book_ID) REFERENCES ADD_Books(Book_ID),
    CONSTRAINT FK_BorrowedBooks_Staff FOREIGN KEY (Staff_ID) REFERENCES Staff(Staff_ID)
);

-- Create ReturnBook table
CREATE TABLE ReturnBook (
    Return_ID INT IDENTITY(1,1) PRIMARY KEY,
    Borrow_ID INT NOT NULL,
    Member_ID INT NOT NULL,
    ReturnDate DATE NOT NULL DEFAULT GETDATE(),
    FineAmount DECIMAL(10,2) DEFAULT 0.00,
    Staff_ID INT NOT NULL,
    CONSTRAINT FK_ReturnBook_Borrow FOREIGN KEY (Borrow_ID) REFERENCES BorrowedBooks(Borrow_ID),
    CONSTRAINT FK_ReturnBook_Member FOREIGN KEY (Member_ID) REFERENCES Member(Member_ID),
    CONSTRAINT FK_ReturnBook_Staff FOREIGN KEY (Staff_ID) REFERENCES Staff(Staff_ID)
);
GO

-- Procedure to check out a book
CREATE PROCEDURE CheckOutBook
    @BookID INT,
    @MemberID INT,
    @StaffID INT
AS
BEGIN
    BEGIN TRANSACTION;
    
    -- Check if book is available
    IF EXISTS (SELECT 1 FROM ADD_BOOKS WHERE Book_ID = @BookID AND BOOK_Status = 'Available' AND AvailableCopies > 0)
    BEGIN
        -- Insert into BorrowedBooks
        INSERT INTO BorrowedBooks (Member_ID, Book_ID, Staff_ID)
        VALUES (@MemberID, @BookID, @StaffID);
        
        -- Update book status and available copies
        UPDATE ADD_BOOKS
        SET 
            BOOK_Status = CASE 
                            WHEN AvailableCopies - 1 > 0 THEN 'Available' 
                            ELSE 'Checked Out' 
                          END,
            AvailableCopies = AvailableCopies - 1
        WHERE Book_ID = @BookID;
        
        COMMIT;
        SELECT 'Success' AS Result, 'Book checked out successfully.' AS Message;
    END
    ELSE
    BEGIN
        ROLLBACK;
        SELECT 'Error' AS Result, 'Book is not available for checkout.' AS Message;
    END
END;
GO


CREATE PROCEDURE ReturnBook
    @BorrowID INT,
    @StaffID INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @BookID INT, @MemberID INT, @DueDate DATE;
        
        -- Get book, member IDs and due date
        SELECT @BookID = Book_ID, @MemberID = Member_ID, @DueDate = DueDate
        FROM BorrowedBooks
        WHERE Borrow_ID = @BorrowID AND IsReturned = 0;
        
        IF @BookID IS NOT NULL
        BEGIN
            -- Calculate fine
            DECLARE @FineAmount DECIMAL(10,2) = CASE 
                                                WHEN GETDATE() > @DueDate 
                                                THEN DATEDIFF(DAY, @DueDate, GETDATE()) * 10 -- Rs. 10 per day
                                                ELSE 0 
                                             END;
            
            -- Insert into ReturnBook table with Member_ID
            INSERT INTO ReturnBook (Borrow_ID, Member_ID, FineAmount, Staff_ID)
            VALUES (@BorrowID, @MemberID, @FineAmount, @StaffID);
            
            -- Update BorrowedBooks to mark as returned
            UPDATE BorrowedBooks
            SET IsReturned = 1
            WHERE Borrow_ID = @BorrowID;
            
            -- Update book status and available copies
            UPDATE ADD_BOOKS
            SET 
                AvailableCopies = AvailableCopies + 1,
                BOOK_Status = 'Available'
            WHERE Book_ID = @BookID;
            
            COMMIT;
            SELECT 'Success' AS Result, 'Book returned successfully. Fine calculated if applicable.' AS Message;
        END
        ELSE
        BEGIN
            ROLLBACK;
            SELECT 'Error' AS Result, 'Borrow record not found or book already returned.' AS Message;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
            
        SELECT 'Error' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO


-- Insert sample data into Member table
INSERT INTO Member (Name, Email, Phone, Address, MembershipDate)
VALUES 
('Rahul Sharma', 'rahul.sharma@example.com', '9876543210', '123 Main St, Mumbai', '2022-01-15'),
('Priya Patel', 'priya.patel@example.com', '8765432109', '456 Oak Ave, Delhi', '2022-02-20'),
('Amit Singh', 'amit.singh@example.com', '7654321098', '789 Pine Rd, Bangalore', '2022-03-10'),
('Neha Gupta', 'neha.gupta@example.com', '6543210987', '321 Elm St, Hyderabad', '2022-04-05'),
('Vikram Joshi', 'vikram.joshi@example.com', '5432109876', '654 Maple Dr, Chennai', '2022-05-12');

-- Insert sample data into Staff table
INSERT INTO Staff (Name, Email)
VALUES 
('Arun Kumar', 'arun.kumar@library.com'),
('Meena Desai', 'meena.desai@library.com'),
('Sanjay Verma', 'sanjay.verma@library.com');

-- Insert sample data into ADD_BOOKS table
INSERT INTO ADD_BOOKS (ISBN, Title, Author_name, BOOK_Status, TotalCopies, AvailableCopies)
VALUES 
('978-0061120084', 'To Kill a Mockingbird', 'Harper Lee', 'Available', 5, 5),
('978-0451524935', '1984', 'George Orwell', 'Available', 3, 3),
('978-0743273565', 'The Great Gatsby', 'F. Scott Fitzgerald', 'Available', 4, 4),
('978-0307474278', 'The Da Vinci Code', 'Dan Brown', 'Available', 2, 2),
('978-1400033416', 'The Kite Runner', 'Khaled Hosseini', 'Available', 3, 3),
('978-0743477109', 'The Alchemist', 'Paulo Coelho', 'Available', 4, 4),
('978-0062315007', 'The Monk Who Sold His Ferrari', 'Robin Sharma', 'Available', 2, 2),
('978-8172234980', 'The Immortals of Meluha', 'Amish Tripathi', 'Available', 3, 3),
('978-0143106636', 'Midnight''s Children', 'Salman Rushdie', 'Available', 2, 2),
('978-8189988804', 'The Palace of Illusions', 'Chitra Banerjee Divakaruni', 'Available', 3, 3);

-- Insert sample data into BorrowedBooks table
INSERT INTO BorrowedBooks (Member_ID, Book_ID, Staff_ID, IssueDate, DueDate, IsReturned)
VALUES 
(1, 1, 1, '2023-01-10', '2023-01-24', 1),
(2, 3, 2, '2023-01-15', '2023-01-29', 0),
(3, 5, 3, '2023-01-20', '2023-02-03', 0),
(4, 2, 1, '2023-01-25', '2023-02-08', 1),
(5, 4, 2, '2023-02-01', '2023-02-15', 0);

-- Insert sample data into ReturnBook table
INSERT INTO ReturnBook (Borrow_ID, Member_ID, ReturnDate, FineAmount, Staff_ID)
VALUES 
(1, 1, '2023-01-22', 0.00, 1),
(4, 4, '2023-02-10', 20.00, 2);
GO





from app.core.database import get_db_connection

def fix_partners():
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Find partners without AccountID
        cursor.execute("SELECT PartnerID, PartnerName, PartnerType FROM [Sales].[Partners] WHERE AccountID IS NULL")
        partners = cursor.fetchall()
        
        for p in partners:
            partner_id, name, ptype = p
            print(f"Fixing partner: {name} (ID: {partner_id}, Type: {ptype})")
            
            # Find parent account (Customers or Vendors)
            parent_name = "العملاء" if ptype == "Customer" else "الموردين"
            cursor.execute("SELECT AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountName LIKE ?", ('%' + parent_name + '%',))
            parent_row = cursor.fetchone()
            
            if not parent_row:
                print(f"  Parent account for {ptype} not found! Skipping.")
                continue
                
            parent_id = parent_row[0]
            
            # Create account
            cursor.execute("""
                INSERT INTO [Accounting].[ChartOfAccounts] 
                (AccountCode, AccountName, ParentAccountID, AccountType, AccountLevel, IsTransactional, CreatedBy)
                VALUES 
                (CONCAT('10', ?, ABS(CHECKSUM(NEWID())) % 10000), ?, ?, 'Asset', 3, 1, 1)
            """, (partner_id, name, parent_id))
            
            # Get the new AccountID
            cursor.execute("SELECT SCOPE_IDENTITY()")
            new_acc_id = cursor.fetchone()[0]
            
            # Update Partner
            cursor.execute("UPDATE [Sales].[Partners] SET AccountID = ? WHERE PartnerID = ?", (new_acc_id, partner_id))
            print(f"  -> Created AccountID: {new_acc_id} and linked.")
            
        conn.commit()
        print("Done!")
    except Exception as e:
        conn.rollback()
        print("Error:", e)
    finally:
        conn.close()

if __name__ == "__main__":
    fix_partners()

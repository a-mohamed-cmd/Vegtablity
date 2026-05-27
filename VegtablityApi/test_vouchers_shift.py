import asyncio
from app.core.database import get_db_connection

def test():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT VoucherID, VoucherType, Amount, ShiftID, IsPosted
        FROM [Accounting].[Vouchers]
        ORDER BY VoucherID DESC
    """)
    for row in cursor.fetchmany(10):
        print(row)
        
test()

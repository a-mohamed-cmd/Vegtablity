import asyncio
from app.core.database import get_db_connection

def test():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        EXEC [Sales].[sp_Shift_GetSummary] @ShiftID = 4
    """)
    row = cursor.fetchone()
    if row:
        columns = [column[0] for column in cursor.description]
        result = dict(zip(columns, row))
        print("RESULT:")
        for k, v in result.items():
            print(f"  {k}: {v}")
    else:
        print("No row returned.")
        
test()

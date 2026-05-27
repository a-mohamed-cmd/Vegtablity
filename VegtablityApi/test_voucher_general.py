import os
import sys
from datetime import datetime

# Setup FastAPI environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import get_db_connection
from app.services.voucher_service import VoucherService

def test_save_voucher():
    print("Testing general voucher save...")
    try:
        service = VoucherService()
        result = service.save_general_voucher(
            voucher_type="Receipt",
            total_amount=5.0,
            account_id=35,
            user_id=1,  # dummy user_id
            shift_id=5,
            description="hj",
            payment_method="46"
        )
        print("Success:", result)
    except Exception as e:
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_save_voucher()

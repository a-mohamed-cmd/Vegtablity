import asyncio
from app.services.voucher_service import VoucherService
import sys

sys.stdout.reconfigure(encoding='utf-8')

async def test():
    service = VoucherService()
    accounts = service.get_accounts_for_voucher()
    
    for acc in accounts:
        acc_id = acc['AccountID']
        print(f"Testing AccountID: {acc_id} - {acc['AccountName']}")
        try:
            res1 = service.bulk_pay(
                partner_id=1,
                voucher_type="Receipt",
                total_amount=1.0,
                account_id=acc_id,
                user_id=1,
                shift_id=1,
                description="Test Receipt",
                allocations=[]
            )
            print("  Receipt SUCCESS")
        except Exception as e:
            print("  Receipt ERROR:", e)
            
        try:
            res2 = service.bulk_pay(
                partner_id=1,
                voucher_type="Payment",
                total_amount=1.0,
                account_id=acc_id,
                user_id=1,
                shift_id=1,
                description="Test Payment",
                allocations=[]
            )
            print("  Payment SUCCESS")
        except Exception as e:
            print("  Payment ERROR:", e)

asyncio.run(test())

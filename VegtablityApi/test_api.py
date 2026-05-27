import asyncio
from app.services.voucher_service import VoucherService

async def test():
    service = VoucherService()
    try:
        res = service.bulk_pay(
            partner_id=1,
            voucher_type="Receipt",
            total_amount=100.0,
            account_id=1,
            user_id=1,
            shift_id=1,
            description="Test",
            allocations=[{"InvID": 1, "Amount": 100.0}]
        )
        print("SUCCESS:", res)
    except Exception as e:
        print("ERROR:", e)

asyncio.run(test())

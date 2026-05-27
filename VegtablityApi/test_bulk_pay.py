import asyncio
from app.services.voucher_service import VoucherService

def test():
    service = VoucherService()
    try:
        # Example data representing a voucher
        res = service.bulk_pay(
            partner_id=2, # dummy partner id
            voucher_type="Payment",
            total_amount=2.0,
            account_id=1, # dummy account id
            user_id=1,
            shift_id=4, # dummy shift id
            description="Test from script",
            allocations=[]
        )
        print("Success:", res)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    test()

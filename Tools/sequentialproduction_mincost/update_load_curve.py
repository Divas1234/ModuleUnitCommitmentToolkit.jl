import openpyxl
import random

def generate_dual_peak_load_curve(n_days=7, base_min=200.0, morning_peak=330.0, evening_peak=370.0):
    random.seed(42)
    load_values = []

    for day in range(1, n_days + 1):
        is_weekend = (day == 6 or day == 7)
        scale = 0.90 if is_weekend else 1.00

        daily_profile = [
            # 01:00 - 06:00 : Night Off-Peak (Low & Smooth)
            base_min + random.uniform(0, 5),        # 01:00
            base_min + random.uniform(0, 4),        # 02:00
            base_min - 2.0 + random.uniform(0, 3),  # 03:00 (Night valley)
            base_min + random.uniform(0, 3),        # 04:00
            base_min + 5.0 + random.uniform(0, 4),  # 05:00
            base_min + 15.0 + random.uniform(0, 5), # 06:00

            # 07:00 - 09:30 : MORNING PEAK RAMP (早高峰强爬坡区段)
            base_min + 55.0 + random.uniform(0, 6),     # 07:00 (Ramp start)
            morning_peak - 20.0 + random.uniform(0, 5), # 08:00 (Steep ramp up)
            morning_peak + random.uniform(0, 8),        # 09:00 (Morning peak)

            # 10:00 - 16:30 : Midday Plateau (午间平稳)
            morning_peak - 15.0 + random.uniform(0, 5), # 10:00
            morning_peak - 25.0 + random.uniform(0, 6), # 11:00
            morning_peak - 30.0 + random.uniform(0, 5), # 12:00
            morning_peak - 20.0 + random.uniform(0, 6), # 13:00
            morning_peak - 15.0 + random.uniform(0, 5), # 14:00
            morning_peak - 10.0 + random.uniform(0, 6), # 15:00
            morning_peak + 5.0 + random.uniform(0, 5),  # 16:00

            # 17:00 - 20:30 : EVENING PEAK RAMP (晚高峰强爬坡与最高峰)
            evening_peak - 30.0 + random.uniform(0, 6), # 17:00 (Evening ramp start)
            evening_peak - 10.0 + random.uniform(0, 5), # 18:00 (Steep ramp up)
            evening_peak + random.uniform(0, 8),        # 19:00 (Evening peak)
            evening_peak - 15.0 + random.uniform(0, 6), # 20:00

            # 21:00 - 24:00 : Night Ramp Down (夜间退峰)
            evening_peak - 60.0 + random.uniform(0, 6), # 21:00
            base_min + 70.0 + random.uniform(0, 5),     # 22:00
            base_min + 35.0 + random.uniform(0, 4),     # 23:00
            base_min + 10.0 + random.uniform(0, 4)      # 24:00
        ]

        for val in daily_profile:
            load_values.append(round(val * scale, 2))

    return load_values

def main():
    excel_path = "data/data.xlsx"
    print(f"Updating load_curve in {excel_path}...")
    wb = openpyxl.load_workbook(excel_path)
    if "load_curve" not in wb.sheetnames:
        raise ValueError("Sheet 'load_curve' not found in data.xlsx")
    
    ws = wb["load_curve"]
    load_vals = generate_dual_peak_load_curve(n_days=7)
    
    for i, val in enumerate(load_vals, start=1):
        ws.cell(row=i+1, column=1, value=float(i))
        ws.cell(row=i+1, column=2, value=float(val))
    
    wb.save(excel_path)
    print(f"✓ Successfully updated 168-hour dual-peak load curve in {excel_path}!")

if __name__ == "__main__":
    main()

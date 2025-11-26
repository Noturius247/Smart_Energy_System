import json

# Field name mapping from old to new format
field_mapping = {
    "averagepower": "average_power_w",
    "averagecurrent": "average_current",
    "averagevoltage": "average_voltage",
    "maxpower": "max_power",
    "maxcurrent": "max_current",
    "maxvoltage": "max_voltage",
    "minpower": "min_power",
    "mincurrent": "min_current",
    "minvoltage": "min_voltage",
    "totalreadings": "total_readings"
}

def fix_field_names(obj):
    """Recursively fix field names in the object"""
    if isinstance(obj, dict):
        new_obj = {}
        for key, value in obj.items():
            # Check if this key needs to be renamed
            new_key = field_mapping.get(key, key)
            # Recursively process the value
            new_obj[new_key] = fix_field_names(value)
        return new_obj
    elif isinstance(obj, list):
        return [fix_field_names(item) for item in obj]
    else:
        return obj

# Read the input file
input_file = r'D:\latest update\Smart_Energy_System\SP002_aggregations_WITH_OLD_PRESERVED.json'
output_file = r'D:\latest update\Smart_Energy_System\SP002_aggregations_FIXED.json'

print(f"Reading file: {input_file}")
with open(input_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

print("Fixing field names...")
fixed_data = fix_field_names(data)

print(f"Writing fixed data to: {output_file}")
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(fixed_data, f, indent=2, ensure_ascii=False)

print("Done! Field names have been updated.")
print("\nUpdated fields:")
for old, new in field_mapping.items():
    print(f"  {old} -> {new}")

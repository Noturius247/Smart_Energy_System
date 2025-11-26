const fs = require('fs');

// Field name mapping from old to new format
const fieldMapping = {
    "averagepower": "average_power",
    "average_power_w": "average_power",  // Fix the _w suffix
    "averagecurrent": "average_current",
    "averagevoltage": "average_voltage",
    "maxpower": "max_power",
    "maxcurrent": "max_current",
    "maxvoltage": "max_voltage",
    "minpower": "min_power",
    "mincurrent": "min_current",
    "minvoltage": "min_voltage",
    "totalreadings": "total_readings",
    "totalenergy": "total_energy",
    "totalreadingsinsnapshot": "total_readings_in_snapshot"
};

function fixTimestamp(timestamp) {
    if (typeof timestamp !== 'string') return timestamp;

    // Fix malformed timestamps like "2025-11-26T0000:00" -> "2025-11-26T00:00:00"
    let fixed = timestamp;

    // Pattern: "2025-11-26T0000:00" -> "2025-11-26T00:00:00"
    if (/^\d{4}-\d{2}-\d{2}T\d{4}:\d{2}$/.test(fixed)) {
        const match = fixed.match(/^(\d{4}-\d{2}-\d{2})T(\d{2})(\d{2}):(\d{2})$/);
        if (match) {
            fixed = `${match[1]}T${match[2]}:${match[3]}:${match[4]}`;
        }
    }

    // Add timezone if missing (add +08:00 for Philippine timezone)
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/.test(fixed)) {
        fixed = fixed + '+08:00';
    }

    // Fix Z timezone to +08:00 for consistency
    if (fixed.endsWith('Z')) {
        fixed = fixed.replace('Z', '+08:00');
    }

    return fixed;
}

function fixFieldNames(obj) {
    if (obj === null || obj === undefined) {
        return obj;
    }

    if (Array.isArray(obj)) {
        return obj.map(item => fixFieldNames(item));
    }

    if (typeof obj === 'object') {
        const newObj = {};
        for (const [key, value] of Object.entries(obj)) {
            // Check if this key needs to be renamed
            const newKey = fieldMapping[key] || key;

            // Fix timestamp values
            if (newKey === 'timestamp' || newKey === 'last_updated_utc') {
                newObj[newKey] = fixTimestamp(value);
            } else {
                // Recursively process the value
                newObj[newKey] = fixFieldNames(value);
            }
        }
        return newObj;
    }

    return obj;
}

// Read the input file
const inputFile = 'D:\\latest update\\Smart_Energy_System\\SP002_aggregations_WITH_OLD_PRESERVED.json';
const outputFile = 'D:\\latest update\\Smart_Energy_System\\SP002_aggregations_FIXED.json';

console.log(`Reading file: ${inputFile}`);
const data = JSON.parse(fs.readFileSync(inputFile, 'utf-8'));

console.log("Fixing field names and timestamps...");
const fixedData = fixFieldNames(data);

console.log(`Writing fixed data to: ${outputFile}`);
fs.writeFileSync(outputFile, JSON.stringify(fixedData, null, 2), 'utf-8');

console.log("Done! All fields and timestamps have been updated.");
console.log("\nUpdated fields:");
for (const [old, newName] of Object.entries(fieldMapping)) {
    console.log(`  ${old} -> ${newName}`);
}
console.log("\nTimestamp fixes:");
console.log("  - Fixed malformed timestamps (e.g., T0000:00 -> T00:00:00)");
console.log("  - Added timezone +08:00 where missing");
console.log("  - Converted Z to +08:00");

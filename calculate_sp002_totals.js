const fs = require('fs');

// Read the fixed SP002 data
const inputFile = 'D:\\latest update\\Smart_Energy_System\\SP002_aggregations_FIXED.json';
console.log(`Reading file: ${inputFile}\n`);
const data = JSON.parse(fs.readFileSync(inputFile, 'utf-8'));

// Get the first SP002 section (the main one)
const sp002Data = data.hubs?.SP002;

if (!sp002Data || !sp002Data.aggregations) {
    console.log('No SP002 data found!');
    process.exit(1);
}

const aggregations = sp002Data.aggregations;

// Calculate totals from the most recent data
let totalPower = 0;
let totalEnergy = 0;
let totalVoltage = 0;
let totalCurrent = 0;
let connectedPlugs = 0;
let latestTimestamp = null;

// Get the latest hourly data (most recent hour)
if (aggregations.hourly) {
    const hourlyKeys = Object.keys(aggregations.hourly).sort().reverse();
    if (hourlyKeys.length > 0) {
        const latestHour = aggregations.hourly[hourlyKeys[0]];
        totalPower = latestHour.average_power || 0;
        totalVoltage = latestHour.average_voltage || 0;
        totalCurrent = latestHour.average_current || 0;
        latestTimestamp = latestHour.timestamp;
    }
}

// Get total energy from the latest daily data
if (aggregations.daily) {
    const dailyKeys = Object.keys(aggregations.daily).sort().reverse();
    if (dailyKeys.length > 0) {
        const latestDay = aggregations.daily[dailyKeys[0]];
        totalEnergy = latestDay.total_energy || 0;
    }
}

// Calculate cost (assuming Philippine rate: ₱12 per kWh)
const costPerKwh = 12;
const totalCost = totalEnergy * costPerKwh;

// Count connected plugs (assume 1 for SP002)
connectedPlugs = 1;

// Display results
console.log('╔════════════════════════════════════════════╗');
console.log('║       SP002 CURRENT TOTALS SUMMARY        ║');
console.log('╚════════════════════════════════════════════╝\n');

console.log('Connected Plugs:', connectedPlugs);
console.log('Total Power:', totalPower.toFixed(2), 'W');
console.log('Total Voltage:', totalVoltage.toFixed(2), 'V');
console.log('Total Current:', totalCurrent.toFixed(2), 'A');
console.log('Total Energy:', totalEnergy.toFixed(2), 'kWh');
console.log('Total Cost: ₱' + totalCost.toFixed(2));

if (latestTimestamp) {
    console.log('\nLatest Update:', latestTimestamp);
}

console.log('\n' + '═'.repeat(46));
console.log('DETAILED BREAKDOWN:');
console.log('═'.repeat(46));

// Show recent hourly data
if (aggregations.hourly) {
    console.log('\n📊 RECENT HOURLY DATA (Last 5 hours):');
    const hourlyKeys = Object.keys(aggregations.hourly).sort().reverse().slice(0, 5);
    hourlyKeys.forEach(key => {
        const hour = aggregations.hourly[key];
        console.log(`\n  ${key}:`);
        console.log(`    Power: ${hour.average_power?.toFixed(2) || 0} W`);
        console.log(`    Voltage: ${hour.average_voltage?.toFixed(2) || 0} V`);
        console.log(`    Current: ${hour.average_current?.toFixed(2) || 0} A`);
        console.log(`    Energy: ${hour.total_energy?.toFixed(2) || 0} kWh`);
    });
}

// Show recent daily data
if (aggregations.daily) {
    console.log('\n\n📅 RECENT DAILY DATA (Last 3 days):');
    const dailyKeys = Object.keys(aggregations.daily).sort().reverse().slice(0, 3);
    dailyKeys.forEach(key => {
        const day = aggregations.daily[key];
        console.log(`\n  ${key}:`);
        console.log(`    Power: ${day.average_power?.toFixed(2) || 0} W`);
        console.log(`    Voltage: ${day.average_voltage?.toFixed(2) || 0} V`);
        console.log(`    Current: ${day.average_current?.toFixed(2) || 0} A`);
        console.log(`    Energy: ${day.total_energy?.toFixed(2) || 0} kWh`);
        console.log(`    Cost: ₱${((day.total_energy || 0) * costPerKwh).toFixed(2)}`);
    });
}

console.log('\n' + '═'.repeat(46) + '\n');

document.addEventListener('DOMContentLoaded', function() {
    const ctx = document.getElementById('telematicsChart').getContext('2d');
    const telematicsChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Speed (mph)',
                data: [],
                borderColor: 'rgba(75, 192, 192, 1)',
                fill: false
            }]
        },
        options: {
            scales: {
                x: {
                    type: 'time',
                    time: {
                        unit: 'minute'
                    }
                },
                y: {
                    beginAtZero: true
                }
            }
        }
    });

    async function fetchTelematicsData() {
        try {
            const response = await fetch('/api/telematics');
            const data = await response.json();
            telematicsChart.data.labels.push(data.timestamp);
            telematicsChart.data.datasets[0].data.push(data.speed);
            telematicsChart.update();
        } catch (error) {
            console.error('Error fetching telematics data:', error);
        }
    }

    setInterval(fetchTelematicsData, 60000); // Fetch every minute
});

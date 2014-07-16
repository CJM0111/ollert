var WipChartBuilder = (function () {
  var buildChart = function (options) {
    $('#wipContainer').highcharts({
      chart: {
        type: 'bar'
      },
      title: {
        text: 'Work In Progress'
      },
      subtitle: {
        text: 'WIP'
      },
      xAxis: {
        categories: options.categories,
        title: {
          text: null
        }
      },
      yAxis: {
        min: 0,
        title: {
          text: 'Cards',
          align: 'high'
        },
        labels: {
          overflow: 'justify'
        }
      },
      tooltip: {
        valueSuffix: ' Cards'
      },
      plotOptions: {
        bar: {
          dataLabels: {
            enabled: true
          }
        }
      },
      credits: {
        enabled: false
      },
      series: options.counts
    });
  }

  return {
    build: buildChart
  }
}());
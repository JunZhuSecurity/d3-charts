(function(){

    var margin = {top: 20, right: 30, bottom: 30, left: 40};
    var width = 1024 - margin.left - margin.right;
    var height = 400 - margin.top - margin.bottom;

    function createAxis(chart, scaleX, scaleY) {
        var xAxis = d3.svg.axis()
            .scale(scaleX)
       //     .tickFormat(d3.time.format("%H:%M"))
            .orient("bottom");

        chart.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0," + height + ")")
            .call(xAxis);

        var yAxis = d3.svg.axis().scale(scaleY).orient("left");

        chart.append("g").attr("class", "y axis").call(yAxis)
            .append("text").text("Used #CPU").attr("class", "label")
            .attr("transform", "rotate(-90)")
            .attr("y", 16)
          //  .attr("x", -height / 2)
            .style("text-anchor", "end");
    }

    function createChart(data) {
        var scaleX = d3.time.scale()
            .domain([data.time[0], data.time[data.time.length - 1]])
            .range([0, width]);
        var scaleY = d3.scale.linear()
            .domain([0,8])
            .range([height, 0]);

        var chart = d3.select("#chart")
            .append('svg:svg')
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        createAxis(chart, scaleX, scaleY);

        var line = d3.svg.line()
            .interpolate("basis")
            .x(function(d, i) {
                return scaleX(data.time[i]); })
            .y(function(d) {
                return scaleY(d); });

        chart.append("path")
             .datum(data.cpu)
             .attr("class", "cpu-line")
             .attr("d", line);

    }

    function scatter(data) {
        // i'm using 5x5 rects as data point
        scatter = chart.append("g").attr("transform","translate(-2, -2)");

      scatter.selectAll(".cpu").data(ydata).enter().append("rect")
           .attr("class", "cpu")
           .attr("x", function(d, i) {return scaleX(data.time[i]);})
           .attr("y", function(d) {return scaleY(d);})
           .attr("width", 5)
           .attr("height", 5);

      scatter.selectAll(".cpu2").data(ydata2).enter().append("rect")
           .attr("class", "cpu2")
           .attr("x", function(d, i) {return scaleX(time[i]);})
           .attr("y", function(d) {return scaleY(d);})
           .attr("width", 5)
           .attr("height", 5);
    }


    // Main
    d3.json("data/timeline.json", function(error, json) {
        json.time.forEach(function(t, i, a){a[i] = Date.parse(t) + 3600000;}); // 0100 Offset
        createChart(json);
    });

})();

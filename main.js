
function convert(d) {
    var result = {};
    d3.keys(d).forEach(function(key) {
        result[key] = (key !== 'Time') ? +d[key] : Date.parse(d[key]);
    });
    return result;
}

time = [
"2014-02-28 16:18:51 +0100",
"2014-02-28 16:23:51 +0100",
"2014-02-28 16:48:56 +0100",
"2014-02-28 17:18:58 +0100",
"2014-02-28 17:49:01 +0100",
"2014-02-28 18:18:45 +0100",
"2014-02-28 18:48:44 +0100",
"2014-02-28 19:19:03 +0100",
"2014-02-28 19:49:03 +0100",
"2014-02-28 20:19:00 +0100",
"2014-02-28 20:48:59 +0100",
"2014-02-28 21:18:59 +0100",
"2014-02-28 21:48:58 +0100",
"2014-02-28 22:18:56 +0100"];

time.forEach(function(t, i, a){a[i] = Date.parse(t);});


(function(){
    var ydata = [0,0,0,1,2,4,2,2,6,1,5,5,3,4];
    var ydata2 = [4,5,9,7,6,7,8,2,4,6,7,8,9,7];

    var margin = {top: 20, right: 30, bottom: 30, left: 40};
    var width = 960 - margin.left - margin.right;
    var height = 500 - margin.top - margin.bottom;

    var scaleX = d3.time.scale()
        .domain([time[0], time[time.length - 1]])
        .range([0, width]);
    var scaleY = d3.scale.linear()
        .domain([0,10])
        .range([height, 0]);

    var chart = d3.select("#chart")
        .append('svg:svg')
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    var xAxis = d3.svg.axis()
        .scale(scaleX)
        .tickFormat(d3.time.format("%H:%M"))
        .orient("bottom");

    chart.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis);

    var yAxis = d3.svg.axis().scale(scaleY).orient("left");

    chart.append("g").attr("class", "y axis").call(yAxis)
         .append("text").text("Milliseconds (ms)")
         .attr("transform", "rotate(-90)")
         .attr("y", -margin.left + 13)
         .attr("x", -height / 2)
         .style("text-anchor", "middle");

    var line = d3.svg.line()
        .interpolate("basis")
        .x(function(d, i) {
            return scaleX(time[i]); })
        .y(function(d) {
            return scaleY(d); });

    chart.append("path")
         .datum(ydata)
         .attr("class", "line")
         .attr("d", line);

    scatter = chart.append("g").attr("transform","translate(-2, -2)");

    scatter.selectAll(".cpu").data(ydata).enter().append("rect")
         .attr("class", "cpu")
         .attr("x", function(d, i) {return scaleX(time[i]);})
         .attr("y", function(d) {return scaleY(d);})
         .attr("width", 5)
         .attr("height", 5);

    scatter.selectAll(".cpu2").data(ydata2).enter().append("rect")
         .attr("class", "cpu2")
         .attr("x", function(d, i) {return scaleX(time[i]);})
         .attr("y", function(d) {return scaleY(d);})
         .attr("width", 5)
         .attr("height", 5);


})();

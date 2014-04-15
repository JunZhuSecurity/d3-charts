d3.json("timeline.json", function(error, json) {

    var ONE_DAY = 24 * 60 * 60 * 1000;
    var margin = {top: 20, right: 20, bottom: 20, left: 30};

    function transform_start_stop(json) {
        var date_format = d3.time.format("%Y-%m-%d");
        json.start = +date_format.parse(json.start);
        json.stop = +date_format.parse(json.stop);
    }

    var chart = d3.select("#timeline svg");
    transform_start_stop(json);

    var width = chart.property("offsetWidth") - margin.left - margin.right;
    var height = chart.property("offsetHeight") - margin.top - margin.bottom;

    var scaleX = d3.time.scale.utc().domain([json.start, json.stop]).range([0, width]);
    chart.append("g").attr("class", "x axis")
         .attr("transform", "translate(0, " + height + ")")
         .call(d3.svg.axis().scale(scaleX).orient("bottom"));

    var scale = d3.scale.linear().domain([0, 1]).range([height, 0]);
    chart.append("g").attr("class", "y axis")
        .call(d3.svg.axis().scale(scale).orient("left"))

    var line = d3.svg.line().interpolate("linear").tension(0.9)
        .x(function(d, i) {return scaleX(json.start + ONE_DAY * i); });

    function create_line(data, style) {
        var domain = d3.extent(data);
        domain[0] -= (domain[1] - domain[0]) / 2;
        if (domain[0] < 0) domain[0] = 0;
        domain[1] += 10;
        var scaleY = d3.scale.linear().domain(domain).range([height, 0]);

        line.y(function (d) {return scaleY(d);});
        chart.append("path").attr("class", "line " + style).attr("d", line(data));
    }

    create_line(json.ram_count, "ram");
    create_line(json.cpu_count, "cpu");
    create_line(json.vm_count, "vm");
    create_line(json.storage, "storage");

});






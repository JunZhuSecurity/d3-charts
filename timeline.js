d3.json("timeline.json", function(error, json) {

    var ONE_DAY = 24 * 60 * 60 * 1000;
    var margin = {top: 20, right: 20, bottom: 20, left: 30};
    var date_format = d3.time.format("%Y-%m-%d");

    function transform_start_stop(json) {
        json.start = date_format.parse(json.start);
        json.stop = date_format.parse(json.stop);
    }

    var chart = d3.select("#timeline svg");
    transform_start_stop(json);

    var width = 600 - margin.left - margin.right;
    var height = 250 - margin.top - margin.bottom;

    var scaleX = d3.time.scale.utc().domain([json.start, json.stop]).range([0, width]);
    chart.append("g").attr("class", "x axis")
         .attr("transform", "translate(30, " + height + ")")
         .call(d3.svg.axis().scale(scaleX).orient("bottom"));

    var scale = d3.scale.linear().domain([0, 1]).range([height, 0]);
    chart.append("g").attr("class", "y axis")
        .attr("transform", "translate(30, 0)")
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

    function vm_delta_table(json) {

        var data = [];
        var current = json.stop;
        var i = json.vm_added.length - 1;
        while (i >= 0 ) {
            if (json.vm_added[i].length + json.vm_removed[i].length > 0) {
                data.push([current, json.vm_added[i], json.vm_removed[i]]);
            }
            current -= ONE_DAY;
            i -= 1;
        }

        var rows = d3.select('#vm_delta_table').selectAll("tr").data(data).enter();
        var row = rows.append("tr")
        row.append("td").text(function(d){return date_format(new Date(d[0]));});
        row.append("td").text(function(d){return d[1].join(', ');});
        row.append("td").text(function(d){return d[2].join(', ');});
    }

    create_line(json.ram_count, "ram");
    create_line(json.cpu_count, "cpu");
    create_line(json.vm_count, "vm");
    create_line(json.storage, "storage");

    vm_delta_table(json);

    d3.select('#Created').text(json.created);
});






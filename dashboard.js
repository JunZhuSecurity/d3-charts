d3.json("dashboard.json", function(error, json) {

    function summary(group) {
        return '<div>' + group.total +'<span class="unit"> VMs</span></div>' +
               '<div>' + group.storage + '<span class="unit"> GBS</span></div>' +
               '<div class="unit">' + 'Windows 8.1' + ' </div>';
    }

    function cpu_and_ram(group) {
        return '<tr><td></td><td>#CPU</td><td>RAM [GB]</td></tr>' +
               '<tr><td>Total</td>' +
                fraction(group.cpu, "CPU") +
                fraction(group.ram, "RAM") + '</tr>' +
               '<tr><td>VM</td>' +
                fraction(group.cpu.vm, "VM CPU") +
                fraction(group.ram.vm, "VM RAM") + '</tr>';
    }

    var percent = d3.format(".1%");
    function fraction(r, type) {
        return "<td title='" + percent(r.used / r.total) + " Peak " + type + " Usage'>" +
            r.used + " /" + r.total + "</td>";
    }

    function disk_and_net(group) {
        return '<tr><td></td><td>Disk [MB/s]</td><td>Net [MBit/s]</td></tr>' +
               '<tr><td>In</td><td>' + group.disk.in + '</td><td>' + group.net.in + '</td></tr>' +
               '<tr><td>Out</td><td>' + group.disk.out + '</td><td>' + group.net.out + '</td></tr>';
    }

    function cpu_chart(chart) {
        var margin = {top: 20, right: 20, bottom: 20, left: 30};
        var width = 730 - margin.left - margin.right;
        var height = 270 - margin.top - margin.bottom;

        // shared X-Axis
        var scaleX = d3.time.scale.utc()
            .domain([json.start, json.stop]).range([0, width]);

        var xAxis = d3.svg.axis().scale(scaleX).orient("bottom");

        chart = chart.append('svg:svg')
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        chart.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0, " + height + ")")
            .call(xAxis);

        // attach scaleY
        json.groups.forEach(function(group){
            group.cpu.scaleY = d3.scale.linear().domain([0, Math.round(+group.cpu.used + 0.6)]).range([height, 0]);
        });

        function yAxisGenerator(selection) {
            selection.each(function (d){
                var yAxis = d3.svg.axis().scale(d.cpu.scaleY).orient("left");
                d3.select(this).call(yAxis)
            });
        }

        chart.append("g").attr("class", "y axis").call(yAxisGenerator)
            .append("text").text("Used #CPU").attr("class", "label")
            .attr("transform", "rotate(-90)")
            .attr("y", 16)
            .style("text-anchor", "end");

        // Now we attach the path

        var line = d3.svg.line()
            .interpolate("basis")
            .x(function(d, i) {return scaleX(json.start + json.interval * i); });

        function cpu_line_generator(group) {
            line.y(function(d){return group.cpu.scaleY(d);});
            return line(group.cpu.data);
        }

        chart.append("path")
             .attr("class", "cpu-line")
             .attr("d", cpu_line_generator);
    }

    d3.select('#Updated').text(json.stop);
    d3.select('#AppGroups').text(json.groups.length);

    var time_format = d3.time.format("%Y-%m-%d %H:%M:%S %Z");
    json.start = +time_format.parse(json.start);
    json.stop = +time_format.parse(json.stop);
    json.interval = json.interval * 1000;

    var groups = d3.select("#Groups").selectAll("div.row").data(json.groups).enter();

    var group = groups.append("div").attr("class", "row").attr("id", function(d){return d.group;});
    var col1 = group.append("div").attr("class", "col1");
    col1.append("div").attr("class", "group").text(function(d){return d.group;})
        .append("div").attr("class", "summary").html(summary);
    col1.append("div").attr("class", "alias").text(function(d) {return d.alias;});
    col1.append("div").attr("class", "owner").text(function(d) {return d.owner;});

    col1.append("table").attr("class", "kpi-table important highlight").attr("title", "Peak LIVE Usage")
        .html(cpu_and_ram);
    col1.append("table").attr("class", "kpi-table important highlight").attr("title", "Peak LIVE Usage")
        .html(disk_and_net);

    var env_table = col1.append("table").attr("class", "kpi-table env");
    var env = env_table.selectAll("tr").data(function(d){return d.env;}).enter();
    env_table.append("tr").html("<td></td><td>#VM</td><td>#CPU</td><td>RAM [GB]</td>");

    var env_row = env.append("tr");
    for (var i = 0; i < 4; i += 1) {
        env_row.append("td").text(function(d){return d[i];});
    }

    var chart = group.append("div").attr("class", "col2");
    cpu_chart(chart);

});






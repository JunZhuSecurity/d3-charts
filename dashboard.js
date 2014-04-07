d3.json("dashboard.json", function(error, json) {

    function append_kpi(row, tip, html) {
        row.append("div").attr("class", "kpi").attr("title", "Peak " + tip + " usage last 7 days").html(html);
    }

    function append_kpi_space(row) {
        row.append("div").attr("class", "kpi-space");
    }

    function kpi_usage(title, used, total) {
        var percent = Math.round(used / total * 100);
        var value = used + "/" + total;
        return '<div class="sub-value">' + percent + '%</div>' +
               '<div class="title">' + title + '</div>' +
               '<div class="value">' + value + '</div>';
    }

    function kpi_io(title, read, write) {
        return '<div class="title">' + title + '</div>' +
               '<div class="value">' + write + '<span class="read">' + read + '</span></div>';
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

    console.log(json.start);
    console.log(json.stop);
    console.log(json.interval);

    var groups = d3.select("#Groups").selectAll("div.row").data(json.groups).enter();

    var group = groups.append("div").attr("class", "row").attr("id", function(d){return d.group;});
    var kpis = group.append("div").attr("class", "col-md-3");
    kpis.append("div").attr("class", "vmgroup").text(function(d){return d.group;});
    kpis.append("div").attr("class", "owner").text(function(d) {return d.alias + ": " + d.owner;});

    var row = kpis.append("div").attr("class", "kpi-row");
    append_kpi(row, "CPU", function(d){return kpi_usage("CPU", d.cpu.used, d.cpu.total);});
    append_kpi_space(row);
    append_kpi(row, "RAM [GiB]", function(d){return kpi_usage("RAM [GiB]", d.ram.used, d.ram.total);});

    row = kpis.append("div").attr("class", "kpi-row");
    append_kpi(row, "Disk IO [MB/s]", function(d) {return kpi_io('Disk IO [MB/s]', d.disk.read, d.disk.write)});
    append_kpi_space(row);
    append_kpi(row, "Net IO [MB/s]", function(d) {return kpi_io('Net IO [MB/s]', d.net.read, d.net.write)});

    var env_table = kpis.append("table").attr("class", "env");
    var env = env_table.selectAll("tr").data(function(d){return d.env;}).enter();
    env_table.append("tr").html("<td></td><td>VMs</td><td>CPUs</td><td>RAM [GiB]</td>");

    var env_row = env.append("tr");
    for (var i = 0; i < 4; i += 1) {
        env_row.append("td").text(function(d){return d[i];});
    }

    var chart = group.append("div").attr("class", "col-md-9");
    cpu_chart(chart);

});






d3.json("dashboard.json", function(error, json) {

    function summary(group) {
        return '<div>' + group.total +'<span class="unit"> VMs</span></div>' +
               '<div>' + group.storage + '<span class="unit"> GBS</span></div>' +
               '<div class="unit" title="' + group.os[0] + '">' + group.os[1] + ' </div>';
    }

    function cpu_and_ram(group) {
        return '<tr><td></td><td>#CPU</td><td>RAM [GB]</td></tr>' +
               '<tr><td>VM</td>' +
                fraction(group.cpu.vm, "VM CPU") +
                fraction(group.ram.vm, "VM RAM") + '</tr>' +
                '<tr><td>Total</td>' +
                fraction(group.cpu, "CPU") +
                fraction(group.ram, "RAM") + '</tr>';

    }

    var percent = d3.format(".1%");
    function fraction(r, type) {
        return "<td title='" + percent(r.used / r.total) + " Peak " + type + " Usage'>" +
            r.used + "/" + r.total + "</td>";
    }

    function disk_and_net(group) {
        return '<tr><td></td><td>Disk [MB/s]</td><td>Net [MBit/s]</td></tr>' +
               '<tr><td>Read</td><td>' + group.disk.read + '</td><td>' + group.net.received + '</td></tr>' +
               '<tr><td>Wrote</td><td>' + group.disk.wrote + '</td><td>' + group.net.sent + '</td></tr>';
    }

    function cpu_chart(chart) {
        var margin = {top: 20, right: 20, bottom: 20, left: 30};
        var width = 760 - margin.left - margin.right;

        // shared X-Axis
        var scaleX = d3.time.scale.utc()
            .domain([json.start, json.stop]).range([0, width]);

        var xAxis = d3.svg.axis().scale(scaleX).orient("bottom");

        function get_height(d) {
            d.height = this.parentNode.parentNode.offsetHeight - 8;
            d.height /= 1;
            return d.height;
        }

        function translate(d) {
            return "translate(0, " + (d.height - margin.top - margin.bottom) + ")";
        }

        chart = chart.append('svg:svg')
            .attr("width", width + margin.left + margin.right)
            .attr("height", 1).attr("height", get_height)
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        chart.append("g")
            .attr("class", "x axis")
            .attr("transform", translate)
            .call(xAxis);

        // attach scaleY
        json.groups.forEach(function(group){
            group.cpu.scaleY = d3.scale.linear().domain([0, group.cpu.used]).range([group.height - margin.top - margin.bottom - 75, 0]);
            group.ram.scaleY = d3.scale.linear().domain([0, group.ram.used]).range([group.height - margin.top - margin.bottom - 50, 50]);
            group.net.scaleY = d3.scale.linear().domain([0,d3.max([group.net.received, group.net.sent])]).range([group.height - margin.top - margin.bottom - 25, 100]);
            group.disk.scaleY = d3.scale.linear().domain([0,d3.max([group.disk.read, group.net.wrote])]).range([group.height - margin.top - margin.bottom - 0, 150]);
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

        var line = d3.svg.line()
            .interpolate("basis")
            .x(function(d, i) {return scaleX(json.start + json.interval * i); });

        function cpu_line(group) {
            line.y(function(d){return group.cpu.scaleY(d);});
            return line(group.cpu.data);
        }

        function ram_line(group) {
            line.y(function(d){return group.ram.scaleY(d);});
            return line(group.ram.data);
        }

        function received_line(group) {
            line.y(function(d){return group.net.scaleY(d);});
            return line(group.net.data_received);
        }

        function sent_line(group) {
            line.y(function(d){return group.net.scaleY(d);});
            return line(group.net.data_sent);
        }

        function read_line(group) {
            line.y(function(d){return group.disk.scaleY(d);});
            return line(group.disk.data_read);
        }

        function wrote_line(group) {
            line.y(function(d){return group.disk.scaleY(d);});
            return line(group.disk.data_wrote);
        }

        chart.append("path").attr("class", "line read").attr("d", read_line);
        chart.append("path").attr("class", "line wrote").attr("d", wrote_line);
        chart.append("path").attr("class", "line received").attr("d", received_line);
        chart.append("path").attr("class", "line sent").attr("d", sent_line);
        chart.append("path").attr("class", "line ram").attr("d", ram_line);
        chart.append("path").attr("class", "line cpu").attr("d", cpu_line);
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






d3.json("dashboard.json", function(error, json) {

    function append_kpi(row, tip, html) {
        row.append("div").attr("class", "kpi").attr("title", "Peak " + tip + " usage last 10 days").html(html);
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


    var groups = d3.select("#Groups").selectAll("div.row").data(json.groups).enter();

    var group = groups.append("div").attr("class", "row").attr("id", function(d){return d.group;});
    var kpis = group.append("div").attr("class", "col-md-3");
    kpis.append("div").attr("class", "vmgroup").text(function(d){return d.group;});
    kpis.append("div").attr("class", "swimlane").text(function(d) {return d.owner + ": " + d.name;});

    var row = kpis.append("div").attr("class", "kpi-row");
    append_kpi(row, "CPU", function(d){return kpi_usage("CPU", d.cpu.used, d.cpu.total);});
    append_kpi_space(row);
    append_kpi(row, "RAM [GiB]", function(d){return kpi_usage("RAM [GiB]", d.ram.used, d.ram.total);});

    row = kpis.append("div").attr("class", "kpi-row");
    append_kpi(row, "Disk IO [MB/s]", function(d) {return kpi_io('Disk IO [MB/s]', d.disk.read, d.disk.write)});
    append_kpi_space(row);
    append_kpi(row, "Net IO [MB/s]", function(d) {return kpi_io('Disk IO [MB/s]', d.net.read, d.net.write)});


});






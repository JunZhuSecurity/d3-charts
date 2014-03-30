d3.json("dashboard.json", function(error, json) {

    function kpiHtml(title, value) {
        return "<div class='title'>" + title + "</div><div class='value'>" + value + "</div>";
    }

    var groups = d3.select("#Groups").selectAll("div.row").data(json).enter();

    var group = groups.append("div").attr("class", "row").attr("id", function(d){return d.group;});
    var kpis = group.append("div").attr("class", "col-md-3");
    kpis.append("div").attr("class", "vmgroup").text(function(d){return d.group;});
    kpis.append("div").attr("class", "swimlane").text(function(d) {return d.owner + ": " + d.name;});

    var row = kpis.append("div").attr("class", "kpi-row");

    //appendKPI(row, tip, title, value);
    //appendKpiSpace(row);
    //appendKPI()

    row.append("div").attr("class", "kpi").attr("title", "Peak usage last 10 days").html(function(d){
        var title = Math.round(d.cpu.used / d.cpu.total * 100) + "% CPU";
        var value = d.cpu.used + "/" + d.cpu.total;
        return kpiHtml(title, value);
    });
    row.append("div").attr("class", "kpi-space");
    row.append("div").attr("class", "kpi").html(function(d){
        var title = Math.round(d.ram.used / d.ram.total * 100) + "% RAM [GiB]";
        var value = d.ram.used + "/" + d.ram.total;
        return kpiHtml(title, value);
    });

    row = kpis.append("div").attr("class", "kpi-row");
    row.append("div").attr("class", "kpi").attr("title", "Disk").html(function(d){
           var title = Math.round(d.cpu.used / d.cpu.total * 100) + "% CPU";
           var value = d.cpu.used + "/" + d.cpu.total;
           return kpiHtml(title, value);
       });

});






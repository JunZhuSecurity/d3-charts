d3.json("dashboard.json", function(error, json) {

    function kpiHtml(title, value) {
        return "<div class='title'>" + title + "</div><div class='usage'>" + value + "</div>";
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
        return kpiHtml("45% CPU", "234");
    });
    row.append("div").attr("class", "kpi-space");
    row.append("div").attr("class", "kpi").html(function(d){
        return kpiHtml("45% CPU", "234");
    })

});






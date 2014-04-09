(function(){

    function sortGroupBy(id, comparator){
        d3.select(id).on("click", function(){
            d3.select("#Groups").selectAll("div.row").sort(comparator);
            d3.selectAll('#SortBy .active').classed("active", false);
            d3.select(id).classed("active", true);
        });
    }

    sortGroupBy('#SortByCPU', function (a,b) {
        return b.cpu.total - a.cpu.total;
    });

    sortGroupBy('#SortByUnusedCPU', function (a,b) {
        return (b.cpu.total - b.cpu.used) - (a.cpu.total - a.cpu.used);
    });

    sortGroupBy('#SortByRAM', function (a,b) {
        var vma = 0, vmb = 0;
        if (a.env.length > 0) {vma = parseFloat(a.env[0][1]);}
        if (b.env.length > 0) {vmb = parseFloat(b.env[0][1]);}
        return b.ram.total *vmb - a.ram.total * vma;
    });

    sortGroupBy('#SortByUnusedRAM', function (a, b) {
        var vma = 0, vmb = 0;
        if (a.env.length > 0) {vma = parseFloat(a.env[0][1]);}
        if (b.env.length > 0) {vmb = parseFloat(b.env[0][1]);}
        return (b.ram.total - b.ram.used) * vmb - (a.ram.total - a.ram.used) * vma;
    });

    sortGroupBy('#SortByVMCount', function (a, b) {
        var vma = 0, vmb = 0;
        if (a.env.length > 0) {vma = parseFloat(a.env[0][1]);}
        if (b.env.length > 0) {vmb = parseFloat(b.env[0][1]);}
        return vmb - vma;
    });


})();
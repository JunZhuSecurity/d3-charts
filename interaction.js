(function(){

    function sortBy(id, comparator){
        d3.select(id).on("click", function(){
            d3.select("#Groups").selectAll("div.row").sort(comparator);
            d3.selectAll('#SortBy .active').classed("active", false);
            d3.select(id).classed("active", true);
        });
    }

    sortBy('#SortByCPU', function (a,b) {
        return b.cpu.total - a.cpu.total;
    });

    sortBy('#SortByUnusedCPU', function (a,b) {
        return (b.cpu.total - b.cpu.used) - (a.cpu.total - a.cpu.used);
    });

    sortBy('#SortByRAM', function (a,b) {
        return b.ram.total - a.ram.total;
    });

    sortBy('#SortByUnusedRAM', function (a, b) {
        return (b.ram.total - b.ram.used) - (a.ram.total - a.ram.used);
    });

    sortBy('#SortByVMCount', function (a, b) {
        return b.total - a.total;
    });

    sortBy('#SortByUsedStorage', function (a, b) {
        return b.storage.used - a.storage.used;
    });

    sortBy('#SortByProvisionedStorage', function (a, b) {
        return b.storage.used - a.storage.used;
    });


})();
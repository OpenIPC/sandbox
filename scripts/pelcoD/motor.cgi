<hr class="mb-3"/>

<div class="zoom">
<div class="col">
		<button class="btn btn-motor" data-dir="z-">➖</button>
		<button class="btn btn-motor" data-dir="s"  style="opacity: 10%; pointer-events: none;">🔎</button>
		<button class="btn btn-motor" data-dir="z+">➕</button>
	</div>
<div class="col">
		<button class="btn btn-motor" data-dir="n">🔶</button>
		<button class="btn btn-motor" data-dir="s" style="opacity: 10%; pointer-events: none;">✴️</button>
		<button class="btn btn-motor" data-dir="f">🔷</button>
	</div>
</div>

<div class="motor">

	<div class="col">
		<button class="btn btn-motor" data-dir="ul" style="opacity: 0%; pointer-events: none;">↖️</button>
		<button class="btn btn-motor" data-dir="uc">⬆️</button>
		<button class="btn btn-motor" data-dir="ur" style="opacity: 0%; pointer-events: none;">↗️</button>
	</div>
	<div class="col">
		<button class="btn btn-motor" data-dir="lc">⬅️</button>
		<button class="btn btn-motor" data-dir="cc">🆗</button>
		<button class="btn btn-motor" data-dir="rc">➡️</button>
	</div>
	<div class="col">
		<button class="btn btn-motor" data-dir="dl" style="opacity: 0%; pointer-events: none;">↙️</button>
		<button class="btn btn-motor" data-dir="dc">⬇️</button>
		<button class="btn btn-motor" data-dir="dr" style="opacity: 0%; pointer-events: none;">↘️</button>
	</div>
</div>

<script>
function control(dir) {
	let x = dir.includes("l") ? 'left' : dir.includes("r") ? 'right' : dir.includes("d") ? 'down' : dir.includes("u") ? 'up' : 'stop';
	
	fetch('/cgi-bin/j/run.cgi?web=' + btoa('btzoom' +  ' ' + x));
}
function control_zoom(dir) {
	let x = dir.includes("+") ? 'tele' : dir.includes("-") ? 'wide' : dir.includes("n") ? 'near' : dir.includes("f") ? 'far' : 'stop';
	
	
	fetch('/cgi-bin/j/run.cgi?web=' + btoa('btzoom' + ' ' + x));
}

$$(".motor button").forEach(el => {
	el.addEventListener("click", ev => {
		control(ev.target.dataset.dir);
 // Изменяем opacity текущего элемента
        ev.target.style.opacity = "0.4"; // Устанавливаем прозрачность
        
        // Возвращаем opacity обратно через короткое время (опционально)
        setTimeout(() => {
            ev.target.style.opacity = "1";
        }, 150);
	});
});
$$(".zoom button").forEach(el => {
	el.addEventListener("click", ev => {
		control_zoom(ev.target.dataset.dir);
// Изменяем opacity текущего элемента
        ev.target.style.opacity = "0.4"; // Устанавливаем прозрачность
        
        // Возвращаем opacity обратно через короткое время (опционально)
        setTimeout(() => {
            ev.target.style.opacity = "1";
        }, 150);
	});
});

</script>


export default class Modal {
    constructor() {
        this.modal = document.createElement('div');
        this.modal.className = 'modal';
        this.modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <button class="back-button">←</button>
                    <h2></h2>
                    <input type="text" class="search-input" placeholder="">
                </div>
                <div class="modal-body"></div>
            </div>
        `;
        document.body.appendChild(this.modal);

        this.modal.querySelector('.back-button').addEventListener('click', () => this.hide());
        this.searchInput = this.modal.querySelector('.search-input');
        this.searchInput.addEventListener('input', (e) => this.handleSearch(e.target.value));
        
        this.selectedId = null;
    }

    show(title, placeholder, items, renderItem, onSelect, currentId = null) {
        this.modal.querySelector('h2').textContent = title;
        this.searchInput.placeholder = placeholder;
        this.items = items;
        this.renderItem = renderItem;
        this.onSelect = onSelect;
        this.selectedId = currentId;
        this.renderItems(items);
        this.modal.style.display = 'flex';
        this.searchInput.value = '';
        this.searchInput.focus();
    }

    hide() {
        this.modal.style.display = 'none';
        this.searchInput.value = '';
    }

    handleSearch(query) {
        const filtered = this.items.filter(item => 
            item.name.toLowerCase().includes(query.toLowerCase()) ||
            item.symbol?.toLowerCase().includes(query.toLowerCase())
        );
        this.renderItems(filtered);
    }

    renderItems(items) {
        const body = this.modal.querySelector('.modal-body');
        body.innerHTML = items.map((item, index) => {
            const isSelected = item.id === this.selectedId;
            return this.renderItem(item, index);
        }).join('');
        
        body.querySelectorAll('.item').forEach(el => {
            el.addEventListener('click', () => {
                const item = items[el.dataset.index];
                this.selectedId = item.id;
                this.onSelect(item);
                this.hide();
            });
        });
    }
}
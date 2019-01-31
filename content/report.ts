declare const config: ReportConfig
declare const defaults: ReportConfig

function equal(a, b) {
  const ta = typeof a
  const tb = typeof b

  if (ta !== tb) return false

  switch (ta) {
    case 'undefined':
      return true
    case 'number':
    case 'string':
    case 'boolean':
      return a === b
  }

  // both are either array or object here

  const aa = Array.isArray(a)
  const ab = Array.isArray(b)
  if (aa !== ab) return false // must be both arrays or objects

  if (aa) {
    if (a.length !== b.length) return false

  } else {
    if ((a === null) !== (b === null)) return false
    if (Object.keys(a).length !== Object.keys(b).length) return false

  }

  for (const i in a) {
    if (!equal(a[i], b[i])) return false
  }

  return true
}

const report = new class {
  public saved: boolean

  private config: ReportConfig
  private editing: boolean

  constructor() {
    this.editing = false
    this.saved = false

    this.config = JSON.parse(JSON.stringify(config))
    this.update()

    document.getElementById('edit-header').style.display = location.href.match(/^file:/i) ? 'none' : ''
  }

  public dirty() {
    return !equal(config, this.config)
  }

  public toggleEdit() {
    this.log('toggleEdit')
    this.editing = !this.editing

    for (const x of document.getElementsByClassName('edit')) {
      (x as HTMLElement).style.display = this.editing ? 'inline-block' : 'none'
    }

    return false
  }

  public deleteField(field) {
    this.log('deleteField')
    if (this.config.fields.remove.indexOf(field.dataset.type) < 0) this.config.fields.remove.push(field.dataset.type)
    this.update()
    return false
  }

  public setSort(field) {
    this.log('setSort')

    this.config.items.sort = (field.dataset.type === this.config.items.sort || this.config.fields.remove.includes(field.dataset.type)) ? '' : field.dataset.type
    this.update()
    return false
  }

  public restore() {
    this.log('restore')
    this.config = JSON.parse(JSON.stringify(config))
    this.update()
    return false
  }

  public reset() {
    this.log('reset')
    this.config = JSON.parse(JSON.stringify(defaults))
    this.update()
    return false
  }

  public save() {
    if (!this.dirty()) return false

    const backend = (document.getElementById('backend') as HTMLIFrameElement).contentWindow
    if (backend) {
      backend.postMessage(JSON.stringify(this.config), '*')
    } else {
      alert(`backend not available: ${!!document.getElementById('backend')}`)
    }

    return false
  }

  public log(msg) {
    return
    const pre = document.getElementById('log')
    pre.textContent += `${msg}\n`
  }

  private update() {
    this.log('update; dirty=' + this.dirty())

    document.getElementById('save').style.display = this.dirty() ? 'inline-block' : 'none'
    document.getElementById('undo').style.display = !equal(this.config, config) ? 'inline-block' : 'none'
    document.getElementById('reset').style.display = !equal(this.config, defaults) && !equal(config, defaults) ? 'inline-block' : 'none'

    const show: {[key: string]: string} = {}

    for (const field of document.querySelectorAll('[data-type]')) {
      const type = (field as HTMLElement).dataset.type
      show[type] = ''
    }

    for (const type of this.config.fields.remove) {
      show[type] = 'none'
    }

    for (const [type, display] of Object.entries(show)) {
      for (const field of document.getElementsByClassName(type)) {
        (field as HTMLElement).style.display = display
      }
    }

    for (const control of document.querySelectorAll('a > i.material-icons')) {
      if (control.textContent !== 'sort_by_alpha') continue

      if (this.config.items.sort && control.parentElement.dataset.type === this.config.items.sort) {
        control.classList.remove('md-inactive')
        control.classList.remove('md-18')
      } else {
        control.classList.add('md-inactive')
        control.classList.add('md-18')
      }
    }

    if (this.config.items.sort) {
      const container = document.getElementById('report')
      const items = Array.from(container.children)
      this.log(`sorting ${items.length} items`)

      items.sort((a, b) => {
        const selector = (this.config.items.sort === 'title') ? 'h2' : `tr.${this.config.items.sort} td`
        const t = [a, b].map(e => (e.querySelector(selector) || { textContent: ''}).textContent)
        return t[0].localeCompare(t[1])
      })

      for (const item of items) {
        container.appendChild(item)
      }
    }
  }
}

window.onbeforeunload = function(e) { // tslint:disable-line:only-arrow-functions
  return report.dirty() ? true : undefined
}

window.onmessage = function(e) { // tslint:disable-line:only-arrow-functions
  // e.data can be 'saved' or 'error'
  report.log('message: got ' + e.data)

  // this will prevent the onbeforeunload complaining
  window.onbeforeunload = undefined

  // this will reload the report and thereby get the latest saved state
  location.reload(true)
}

// onload does not seem to fire within Zotero
report.log('report loaded')
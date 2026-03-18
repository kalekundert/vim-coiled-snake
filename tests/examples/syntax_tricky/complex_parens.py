_load_groups(
        obj,
        groups=get_meta(obj).layer_groups[:],
        predicate=lambda g: (
            g.is_loaded and 
            _is_selected_by_cls(g.config, config_cls)
        ),
)

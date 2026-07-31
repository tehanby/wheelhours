def track_route(start_point, end_point):
    """
    Function to track the route from start point to end point.
    
    Args:
    start_point (str): The starting point of the route.
    end_point (str): The ending point of the route.
    
    Returns:
    list: A list of points forming the route from start to end. 
         Returns None if no path exists.
    """
    # Simplified example logic
    routes = {
        "A": ["B"],
        "B": ["C", "D"],
        "C": [],
        "D": []
    }
    
    if start_point not in routes or end_point not in routes:
        return None
    
    if start_point == end_point:
        return [start_point]
    
    # Basic DFS approach to find path
    stack = [(start_point, [start_point])]
    while stack:
        (vertex, path) = stack.pop()
        for neighbor in routes[vertex]:
            if neighbor not in path:
                new_path = list(path)
                new_path.append(neighbor)
                if neighbor == end_point:
                    return new_path
                else:
                    stack.append((neighbor, new_path))
    
    return None

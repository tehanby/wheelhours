import bpy

def polish_animation(animation_name):
    """
    Polishes an existing animation to ensure it is smooth and enhances visual appeal.
    
    :param animation_name: Name of the animation to be polished.
    """
    scene = bpy.context.scene
    armature = next((obj for obj in scene.objects if obj.type == 'ARMATURE'), None)
    
    if not armature:
        print("No armature found in the scene.")
        return

    action = bpy.data.actions.get(animation_name)
    if not action:
        print(f"Action '{animation_name}' not found.")
        return

    fcurve_list = action.fcurves
    for fcurve in fcurve_list:
        # Smooth interpolation
        fcurve.interpolation = 'BEZIER'
        
        # Remove overshoots and undershoots
        for keyframe_point in fcurve.keyframe_points:
            left_slope = (keyframe_point.co[1] - fcurve.evaluate(keyframe_point.co[0] - 0.1)) / 0.1
            right_slope = (fcurve.evaluate(keyframe_point.co[0] + 0.1) - keyframe_point.co[1]) / 0.1
            if abs(left_slope) > abs(right_slope):
                keyframe_point.interp = 'LINEAR'
            elif abs(left_slope) < abs(right_slope):
                keyframe_point.interp = 'LINEAR'

    # Apply the polished action back to the armature
    armature.animation_data.action = action

# Example usage
polish_animation('wheelhour_animation')
